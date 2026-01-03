# Pacify

Mobile app that estimates pace (BPM/SPM) from accelerometer data.

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

## Features

- Real-time pace estimation using FFT and Kalman filtering
- Visualizations: time-domain accelerometer data and frequency spectrum
- Simulated sensor mode for testing without hardware
- State machine with sampling/pause cycles (5s sampling, 15s pause)

## Platforms

- Android (requires device with accelerometer)
- iOS (requires device with accelerometer) 
- Linux (simulated mode only)

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) for build and run instructions.

## License

MIT