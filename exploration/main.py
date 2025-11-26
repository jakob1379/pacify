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
WINDOW_SECONDS = 5.0       # View window
MAX_SAMPLES = int(WINDOW_SECONDS * SAMPLE_RATE) # 250 samples
PAUSE_SECONDS = 15.0        # Pause duration

# --- State Machine ---
SAMPLING = "sampling"
PAUSED = "paused"

def generate_running_acceleration(
    target_cadence_low: float = 170.0,
    target_cadence_high: float = 180.0
) -> Iterator[tuple[float, float]]:
    """
    Generates simulated linear acceleration (m/s^2) aht 50Hz.
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

    # --- State Management ---
    current_state = SAMPLING
    last_switch_time = 0

    # Generator instance
    stream = generate_running_acceleration()

    # Setup Plot
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10), constrained_layout=True,
                                   facecolor='#1e1e1e')
    (line,) = ax1.plot([], [], lw=1.0, color="#00ffcc")
    (fft_line,) = ax2.plot([], [], lw=1.0, color="#ffaa00")
    # Vertical line to mark the dominant frequency
    (peak_line,) = ax2.plot([], [], color="#ff5555", lw=2, linestyle="--", zorder=3)
    # Text for dominant frequency
    peak_text = ax2.text(
        0.0, 0.0, "", color="white", fontsize=10, ha="center", va="bottom"
    )
    # Text for current state
    state_text = ax1.text(
        0.5,
        1.05,
        "",
        transform=ax1.transAxes,
        color="white",
        fontsize=14,
        ha="center",
    )

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

    def init() -> tuple:
        line.set_data([], [])
        fft_line.set_data([], [])
        peak_line.set_data([], [])
        peak_text.set_text("")
        cadence_text.set_text("")
        state_text.set_text("")
        return line, fft_line, peak_line, peak_text, cadence_text, state_text

    def update(frame: int) -> tuple:
        nonlocal current_state, last_switch_time

        # Always get the next sample to keep the simulation running
        t, a, actual_cadence = next(stream)

        # --- State Machine Logic ---
        elapsed_time = t - last_switch_time

        if current_state == SAMPLING and elapsed_time > WINDOW_SECONDS:
            current_state = PAUSED
            last_switch_time = t
            x_data.clear()
            y_data.clear()
        elif current_state == PAUSED and elapsed_time > PAUSE_SECONDS:
            current_state = SAMPLING
            last_switch_time = t

        state_text.set_text(f"STATE: {current_state.upper()}")

        # --- Data Handling & Plotting ---
        if current_state == SAMPLING:
            x_data.append(t)
            y_data.append(a)

            # Rolling buffer is implicitly handled by clearing data
            if len(x_data) > MAX_SAMPLES:
                x_data.pop(0)
                y_data.pop(0)

            # --- Time Domain Plot ---
            line.set_data(x_data, y_data)
            cadence_text.set_text(f"Simulated Input: {actual_cadence:.1f} SPM")

            if x_data:
                ax1.set_xlim(x_data[0], x_data[0] + WINDOW_SECONDS)

            # --- Frequency Domain Plot ---
            # Run FFT only when we have a full buffer
            if len(y_data) == MAX_SAMPLES:
                window = np.hanning(MAX_SAMPLES)
                y_windowed = np.array(y_data) * window

                yf = rfft(y_windowed)
                xf = rfftfreq(MAX_SAMPLES, DT)
                fft_magnitude = np.abs(yf)
                fft_magnitude[0] = 0

                fft_line.set_data(xf, fft_magnitude)

                # --- Find and Display Dominant Frequency ---
                min_freq_idx = np.where(xf >= 1.0)[0][0]
                max_freq_idx = np.where(xf <= 5.0)[0][-1]

                peak_idx = np.argmax(fft_magnitude[min_freq_idx:max_freq_idx]) + min_freq_idx
                dominant_freq = xf[peak_idx]
                peak_magnitude = fft_magnitude[peak_idx]

                peak_line.set_data([dominant_freq, dominant_freq], [0, peak_magnitude])
                peak_text.set_position((dominant_freq, peak_magnitude))
                peak_text.set_text(f"{dominant_freq*60:.1f} SPM")

                # Smart autoscale
                relevant_indices = np.where((xf > 1.0) & (xf < 5.0))
                if len(relevant_indices[0]) > 0:
                    local_max = np.max(fft_magnitude[relevant_indices])
                    ax2.set_ylim(0, local_max * 1.2 + 1e-9)

        return line, fft_line, peak_line, peak_text, cadence_text, state_text

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
