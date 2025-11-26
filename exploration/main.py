# simulation_50hz_fixed.py
import math
import random
import sys
from collections.abc import Iterator

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation
from scipy.fft import rfft, rfftfreq

# --- CONSTANTS ---
SAMPLE_RATE = 50.0          # 50 Hz
DT = 1.0 / SAMPLE_RATE      # 0.02 seconds per sample
WINDOW_SECONDS = 10.0       # View window
MAX_SAMPLES = int(WINDOW_SECONDS * SAMPLE_RATE) # 500 samples

def generate_running_acceleration(
    target_cadence_low: float = 170.0,
    target_cadence_high: float = 180.0
) -> Iterator[tuple[float, float]]:
    """
    Generates simulated linear acceleration (m/s^2) at 50Hz.
    Uses Phase Accumulation to prevent signal destruction over time.
    """
    t: float = 0.0
    current_cadence: float = (target_cadence_low + target_cadence_high) / 2

    # NEW: Accumulate phase step-by-step instead of calculating from absolute time
    phase: float = 0.0

    # Physics constants
    gravity_removed_baseline: float = 0.0
    impact_magnitude: float = 12.0

    while True:
        # 1. Simulate Natural Cadence Drift (Random Walk)
        cadence_drift = random.uniform(-0.5, 0.5)
        current_cadence += cadence_drift
        current_cadence = max(target_cadence_low, min(current_cadence, target_cadence_high))

        # Convert Cadence (SPM) to Frequency (Hz)
        freq_hz: float = current_cadence / 60.0

        # 2. Update Phase
        # We add the incremental change for this specific time step
        phase += 2 * math.pi * freq_hz * DT

        # Keep phase bounded to avoid floating point issues after hours of running
        phase %= 2 * math.pi

        # 3. Generate Waveform using accumulated phase
        fundamental = math.sin(phase)

        # Harmonic (2x frequency)
        harmonic = 0.35 * math.sin(2 * phase - 0.5)

        # 4. Add Sensor/Movement Noise
        noise = random.gauss(0, 1.5)

        # Combine
        accel = gravity_removed_baseline + (fundamental + harmonic) * (impact_magnitude / 1.5) + noise

        # Rectify negatives slightly
        if accel < -3.0:
            accel = accel * 0.5

        yield t, accel, current_cadence

        t += DT

def run_visualization() -> None:
    # Data buffers for plotting
    x_data: list[float] = []
    y_data: list[float] = []

    # Generator instance
    stream = generate_running_acceleration()

    # --- Pre-populate data ---
    for _ in range(MAX_SAMPLES):
        t, a, _ = next(stream)
        x_data.append(t)
        y_data.append(a)

    # Setup Plot
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10), constrained_layout=True,
                                   facecolor='#1e1e1e')
    (line,) = ax1.plot([], [], lw=1.0, color="#00ffcc")
    (fft_line,) = ax2.plot([], [], lw=1.0, color="#ffaa00")

    cadence_text = ax1.text(0.02, 0.95, "", transform=ax1.transAxes,
        color="white", fontsize=12, verticalalignment="top")

    # --- Styling ---
    for ax in (ax1, ax2):
        ax.set_facecolor("#1e1e1e")
        ax.grid(True, color="#333333", linestyle="--", alpha=0.5)
        ax.tick_params(colors="gray", which="both")
        for spine in ax.spines.values():
            spine.set_edgecolor("#555555")

    # Top plot: Time domain
    ax1.set_ylim(-10, 25)
    ax1.set_xlim(0, WINDOW_SECONDS)
    ax1.set_title(f"Streaming Accelerometer Data ({int(SAMPLE_RATE)}Hz)", color="white")
    ax1.set_ylabel("Linear Accel ($m/s^2$)", color="white")
    ax1.set_xticklabels([])

    # Bottom plot: Frequency domain (FFT)
    # 180 SPM = 3Hz. We care about the 0-10Hz range mostly.
    ax2.set_xlim(0, 10)
    ax2.set_title("Frequency Spectrum (FFT)", color="white")
    ax2.set_xlabel("Frequency (Hz)", color="white")
    ax2.set_ylabel("Amplitude", color="white")

    # Secondary X-Axis for SPM
    secax = ax2.secondary_xaxis('top', functions=(lambda x: x*60, lambda x: x/60))
    secax.set_xlabel("Cadence (SPM)", color="white")
    secax.tick_params(colors="gray")

    fig.patch.set_facecolor("#1e1e1e")

    def init() -> tuple[plt.Line2D, plt.Line2D, plt.Text]:
        line.set_data([], [])
        fft_line.set_data([], [])
        cadence_text.set_text("")
        return line, fft_line, cadence_text

    def update(frame: int) -> tuple[plt.Line2D, plt.Line2D, plt.Text]:
        # Get next sample
        t, a, actual_cadence = next(stream)

        x_data.append(t)
        y_data.append(a)

        if len(x_data) > MAX_SAMPLES:
            x_data.pop(0)
            y_data.pop(0)

        # --- Time Domain Plot ---
        line.set_data(x_data, y_data)
        cadence_text.set_text(f"Simulated Input: {actual_cadence:.1f} SPM")

        if x_data:
            curr_time = x_data[-1]
            if curr_time > WINDOW_SECONDS:
                ax1.set_xlim(curr_time - WINDOW_SECONDS, curr_time)

        # --- Frequency Domain Plot ---
        if len(y_data) == MAX_SAMPLES:
            # Windowing function to reduce spectral leakage
            # Hanning window is good for general purpose
            window = np.hanning(MAX_SAMPLES)
            y_windowed = np.array(y_data) * window

            yf = rfft(y_windowed)
            xf = rfftfreq(MAX_SAMPLES, DT)
            fft_magnitude = np.abs(yf)

            # Zero out DC component (Gravity/Offset) for scaling
            fft_magnitude[0] = 0

            fft_line.set_data(xf, fft_magnitude)

            # Smart autoscale focusing on the running frequency range
            relevant_indices = np.where((xf > 1.0) & (xf < 5.0))
            if len(relevant_indices[0]) > 0:
                local_max = np.max(fft_magnitude[relevant_indices])
                ax2.set_ylim(0, local_max * 1.2)

        return line, fft_line, cadence_text

    ani = FuncAnimation(
        fig,
        update,
        init_func=init,
        frames=None,
        interval=20,
        blit=True,
        cache_frame_data=False
    )

    try:
        print(f"Starting simulation at {SAMPLE_RATE}Hz...")
        plt.show()
    except KeyboardInterrupt:
        sys.exit(0)

if __name__ == "__main__":
    run_visualization()
