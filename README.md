# Pacify

Pacify is a mobile app that estimates your running pace in steps per minute
(SPM) from your phone's accelerometer.

[![CI](https://github.com/jakob1379/pacify/actions/workflows/ci.yml/badge.svg)](https://github.com/jakob1379/pacify/actions/workflows/ci.yml)

<p align="center">
  <img src=".github/assets/cadence-hero.svg" width="100%"
       alt="A running accelerometer trace is compared with a copy of itself shifted by 11 to 26 samples. Each shift gets a bar for the average difference. The shortest bar, at about 17 samples, is the stride period, shown as 173 steps per minute with 28% confidence. A strip shows the cycle: about 5 seconds of measuring, then a 15 second pause.">
</p>

## Quick start

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

Build, emulator and per-platform setup are in [DEVELOPMENT.md](DEVELOPMENT.md).

## How it works

The animation above uses the app's own algorithm on its simulated running
signal. Each measurement goes through these steps:

1. **Sample.** Pacify reads the accelerometer at 50 Hz and keeps the magnitude
   of each reading.
2. **Compare.** After 256 samples (about 5 seconds) it compares the window with
   shifted copies of itself, one per shift that maps to 120 to 240 SPM. The
   average difference for each shift is the AMDF (Average Magnitude Difference
   Function).
3. **Pick the stride.** The first valley in that curve is the stride period.
   Parabolic interpolation refines it to a fraction of a sample, and the period
   converts to SPM. Valleys that are too shallow (below 10% confidence) are
   treated as no pace.
4. **Smooth.** A time-aware Kalman filter combines the new reading with earlier
   ones.
5. **Pause.** The app waits 15 seconds, keeps the last pace on screen, then
   starts a fresh window.

## Features

- Real-time pace estimation using AMDF and Kalman filtering
- Diagnostics page with the motion trace, the AMDF similarity across BPM, raw
  and filtered BPM, confidence and uncertainty
- Simulated sensor mode for testing without hardware
- Sampling and pause cycle: one 256-sample window (about 5 s), then a 15 s pause

## Platforms

| Platform | Sensor                               |
| -------- | ------------------------------------ |
| Android  | Needs a device with an accelerometer |
| iOS      | Needs a device with an accelerometer |
| Linux    | Simulated mode only                  |

To use simulated data, set `_useSimulation = true` in
`lib/features/cadence_detector/presentation/pages/cadence_page.dart`.

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) for prerequisites, the Nix dev shell,
Makefile targets, tests and troubleshooting.

## License

[MIT](LICENSE)
