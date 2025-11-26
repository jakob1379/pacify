# simulation_50hz.py
import math
import random
import sys
import time
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
    """
    t: float = 0.0
    current_cadence: float = (target_cadence_low + target_cadence_high) / 2

    # Physics constants
    gravity_removed_baseline: float = 0.0
    impact_magnitude: float = 12.0

    while True:
        # 1. Simulate Natural Cadence Drift (Random Walk)
        # We allow small changes every sample to simulate human irregularity
        cadence_drift = random.uniform(-0.5, 0.5)
        current_cadence += cadence_drift

        # Clamp cadence to target zone
        current_cadence = max(target_cadence_low, min(current_cadence, target_cadence_high))

        # Convert Cadence (SPM) to Frequency (Hz)
        # 180 SPM = 3.0 Hz
        freq_hz: float = current_cadence / 60.0

        # 2. Generate Waveform (approximating vertical acceleration)
        # Fundamental (the stride)
        fundamental = math.sin(2 * math.pi * freq_hz * t)

        # Harmonic (the impact shock - sharpens the peak)
        # At 50Hz, we can reasonably capture the 2nd harmonic
        harmonic = 0.35 * math.sin(4 * math.pi * freq_hz * t - 0.5)

        # 3. Add Sensor/Movement Noise
        # Random gaussian noise to simulate sensor jitter and surface unevenness
        noise = random.gauss(0, 1.5)

        # Combine
        accel = gravity_removed_baseline + (fundamental + harmonic) * (impact_magnitude / 1.5) + noise

        # Rectify negatives slightly (running creates high positive Gs, lower negative Gs)
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

    # --- Pre-populate data for the first window ---
    for _ in range(MAX_SAMPLES):
        t, a, _ = next(stream)
        x_data.append(t)
        y_data.append(a)

    # Setup Plot
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10), constrained_layout=True,
                                   facecolor='#1e1e1e')
    (line,) = ax1.plot([], [], lw=1.0, color="#00ffcc")  # Cyan line
    (fft_line,) = ax2.plot([], [], lw=1.0, color="#ffaa00")  # Orange line

    # Text annotation for live cadence
    cadence_text = ax1.text(
        0.02,
        0.95,
        "",
        transform=ax1.transAxes,
        color="white",
        fontsize=12,
        verticalalignment="top",
    )

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
    ax1.set_xticklabels([])  # Remove x-axis labels to avoid overlap

    # Bottom plot: Frequency domain (FFT)
    ax2.set_xlim(0, SAMPLE_RATE / 2)  # Nyquist frequency
    ax2.set_title("Frequency Spectrum (FFT)", color="white")
    ax2.set_xlabel("Frequency (Hz)", color="white")
    ax2.set_ylabel("Amplitude", color="white")

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

        # Rolling buffer: remove old data if exceeding window size
        if len(x_data) > MAX_SAMPLES:
            x_data.pop(0)
            y_data.pop(0)

        # --- Time Domain Plot ---
        line.set_data(x_data, y_data)
        cadence_text.set_text(f"Simulated Input: {actual_cadence:.1f} SPM")

        # Slide X-axis window smoothly
        if x_data:
            curr_time = x_data[-1]
            if curr_time > WINDOW_SECONDS:
                ax1.set_xlim(curr_time - WINDOW_SECONDS, curr_time)

        # --- Frequency Domain Plot ---
        if len(y_data) == MAX_SAMPLES:
            # Compute FFT
            yf = rfft(y_data)
            xf = rfftfreq(MAX_SAMPLES, DT)
            
            # We only care about magnitude
            fft_magnitude = np.abs(yf)
            
            fft_line.set_data(xf, fft_magnitude)

            # --- Autoscale FFT Y-axis ---
            # Add a small margin for better visualization
            max_amplitude = np.max(fft_magnitude)
            ax2.set_ylim(0, max_amplitude * 1.1 + 1e-9)



        return line, fft_line, cadence_text

    # Animation Loop
    # interval is in milliseconds. 50Hz = 20ms
    ani = FuncAnimation(
        fig,
        update,
        init_func=init,
        frames=None,
        interval=20,  # 20ms = 50Hz
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
