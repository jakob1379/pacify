# Development Guide

This guide covers how to set up, build, and run the Pacify app on Android and iOS.

## Prerequisites

### Flutter SDK
- Flutter 3.38.3 or later (check with `flutter --version`)
- Dart SDK included with Flutter

### Android Development
- **Android Studio** (recommended) or VS Code with Flutter/Dart plugins
- **Android SDK** (API 36 minimum)
- **Java JDK 17** (required by Gradle)
- Optional: Android emulator or physical device with USB debugging enabled

### iOS Development (macOS only)
- **Xcode 15+** (from Mac App Store)
- **CocoaPods** (`sudo gem install cocoapods`)
- Optional: iOS simulator or physical device with developer mode enabled

### Nix Development Environment (Optional)
The project includes a Nix flake for reproducible development environments:
```bash
nix develop
```

The flake includes Android SDK, Flutter, Java JDK, and Android Studio. To enable Android emulator support, modify `flake.nix`:
- Set `includeEmulator = true`
- Set `includeSystemImages = true`

## Setting Up

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd pacify
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Verify setup**
   ```bash
   flutter doctor
   ```
   Ensure all required components (Flutter, Android toolchain, Xcode) are marked as available.

## Android Development

### Running on Android Emulator

1. **Start an Android emulator**
   - Open Android Studio → AVD Manager
   - Create a virtual device (recommended: Pixel 6, API 36)
   - Start the emulator

2. **Run the app**
   ```bash
   # Using Flutter CLI
   flutter run -d android

   # Using Makefile
   make run-android
   ```

### Running on Physical Android Device

1. **Enable Developer Options**
   - Go to Settings → About Phone → Tap "Build Number" 7 times
   - Go to Settings → Developer Options → Enable "USB Debugging"

2. **Connect device**
   ```bash
   # Check device is recognized
   flutter devices

   # Run the app
   flutter run -d <device-id>
   ```

### Building for Android

```bash
# Debug APK (for testing)
flutter build apk

# Release APK (for distribution)
flutter build apk --release

# App Bundle (for Google Play)
flutter build appbundle --release

# Using Makefile
make build-android
```

### Android-Specific Notes

- **Foreground Service**: The app uses a foreground service for continuous sensor reading on Android. This requires the `FOREGROUND_SERVICE` permission and shows a persistent notification while active.
- **Sensor Access**: The app uses accelerometer data (normal permission, no runtime request needed).
- **Simulated Mode**: By default, the app uses simulated sensor data. To use real accelerometer, change `_useSimulation = false` in `cadence_page.dart`.

## iOS Development

### Running on iOS Simulator (macOS only)

1. **Start iOS Simulator**
   ```bash
   open -a Simulator
   ```

2. **Run the app**
   ```bash
   # Using Flutter CLI
   flutter run -d ios

   # Using Makefile
   make run-ios
   ```

### Running on Physical iOS Device (macOS only)

1. **Configure Xcode**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select your development team in Signing & Capabilities
   - Connect your iPhone via USB

2. **Run the app**
   ```bash
   flutter run -d <device-id>
   ```

### Building for iOS

```bash
# Debug build
flutter build ios --debug

# Release build (requires macOS and Xcode)
flutter build ios --release

# Using Makefile
make build-ios
```

### iOS-Specific Notes

- **Background Modes**: iOS requires background modes configuration for continuous sensor reading.
- **Privacy Permissions**: The app requires motion & fitness permissions in Info.plist.
- **Simulator Limitations**: iOS simulators don't have real accelerometers; use simulated mode.

## Linux Development

The app can run on Linux desktop with simulated sensor data only (real accelerometer not available).

### Running on Linux
```bash
# Enable Linux desktop support
flutter create --platforms=linux .

# Run the app
flutter run -d linux
```

### Linux-Specific Notes
- **Simulated Mode Only**: Linux uses simulated sensor data (no real accelerometer access)
- **Platform Support**: Requires Flutter with Linux desktop enabled
- **Dependencies**: Ensure GLFW and GTK development libraries are installed

## Development Workflow

### Using Makefile Commands

The project includes a Makefile with common tasks:

```bash
# Install dependencies and generate code
make setup

# Run static analysis
make analyze

# Format code
make format

# Run tests
make test

# Clean build artifacts
make clean

# See all available commands
make help
```

### Code Structure

- **`lib/features/cadence_detector/`** - Pace estimation feature
  - `data/services/` - Sensor services (real and simulated)
  - `presentation/bloc/` - State management
  - `presentation/pages/` - UI screens
- **`lib/main.dart`** - App entry point

### Switching Sensor Modes

The app supports two sensor modes:

1. **Simulated Mode** (default): Generates synthetic accelerometer data for testing
   ```dart
   // In cadence_page.dart
   static const bool _useSimulation = true;  // Change to false for real sensor
   ```

2. **Real Sensor Mode**: Uses device accelerometer (requires physical device)
   ```dart
   static const bool _useSimulation = false;
   ```

**State Machine**: The app implements a sampling/pause cycle (5 seconds sampling, 15 seconds pause) matching the original Python simulation. During pause, visualizations are cleared and the last BPM is displayed.

## Platform-Specific Configuration

### Android (`android/app/build.gradle` & `AndroidManifest.xml`)
- Minimum SDK: 21
- Target SDK: 36
- Foreground service permission
- Accelerometer permission

### iOS (`ios/Runner/Info.plist`)
- Minimum iOS: 12.0
- Motion & fitness privacy descriptions
- Background modes for location updates

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Running on Multiple Devices
```bash
# Run on all connected devices
flutter run -d all
```

## Troubleshooting

### Common Android Issues

**"Gradle build failed"**
```bash
# Clean gradle cache
make clean-gradle

# Accept Android licenses
flutter doctor --android-licenses
```

**"Device not recognized"**
```bash
# Restart ADB server
adb kill-server && adb start-server
```

### Common iOS Issues

**"No development team selected"**
- Open `ios/Runner.xcworkspace` in Xcode
- Select your team in Signing & Capabilities

**"CocoaPods not installed"**
```bash
sudo gem install cocoapods
cd ios && pod install
```

### Flutter Issues

**"Packages out of date"**
```bash
flutter clean
flutter pub get
```

**"Build runner conflicts"**
```bash
make gen-clean
```

## Deployment

### Android
1. Update version in `android/app/build.gradle`
2. Generate signing key if not exists
3. Build release APK or App Bundle
4. Upload to Google Play Console

### iOS
1. Update version in `ios/Runner/Info.plist`
2. Create provisioning profiles in Apple Developer Portal
3. Archive and upload via Xcode or Fastlane

## Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Android Developer Guide](https://developer.android.com/guide)
- [iOS Developer Guide](https://developer.apple.com/ios/)
- [BLoC State Management](https://bloclibrary.dev/)

---
*Last updated: 2026-01-03*
