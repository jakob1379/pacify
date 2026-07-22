import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'sensor_service.dart';

/// Simulated sensor service that generates accelerometer data similar to
/// the Python exploration simulation.
class SimulatedSensorService extends SensorService {
  static const double _dt = 1.0 / SensorService.samplingRate;
  static const double _targetCadenceLow = 170.0;
  static const double _targetCadenceHigh = 180.0;
  static const double _impactMagnitude = 12.0;
  static const double _gravityRemovedBaseline = 0.0;
  static const double _noiseStdDev = 1.5;
  static const double _harmonicCoefficient = 0.35;
  static const double _harmonicPhaseShift = -0.5;
  static const double _cadenceDriftRange = 0.5;

  final Random _random = Random();

  double _nextGaussian() {
    // Central limit theorem approximation: sum of 12 uniform random numbers - 6
    var sum = 0.0;
    for (var i = 0; i < 12; i++) {
      sum += _random.nextDouble();
    }
    return sum - 6.0;
  }

  final StreamController<AccelerometerEvent> _controller =
      StreamController<AccelerometerEvent>.broadcast();
  Timer? _timer;

  double _currentCadence = (_targetCadenceLow + _targetCadenceHigh) / 2;
  double _phase = 0.0;

  SimulatedSensorService() {
    // Start generating samples when stream gets first listener
    _controller.onListen = () {
      if (_timer == null || !_timer!.isActive) {
        _timer = Timer.periodic(
          Duration(
            microseconds:
                Duration.microsecondsPerSecond ~/ SensorService.samplingRate,
          ),
          (_) => _generateSample(),
        );
      }
    };
    // Stop timer when stream loses all listeners
    _controller.onCancel = () {
      _timer?.cancel();
      _timer = null;
    };
  }

  @override
  Stream<AccelerometerEvent> get accelerometerStream => _controller.stream;

  @override
  Future<void> startListening() async {
    if (_timer == null || !_timer!.isActive) {
      _timer = Timer.periodic(
        Duration(
          microseconds:
              Duration.microsecondsPerSecond ~/ SensorService.samplingRate,
        ),
        (_) => _generateSample(),
      );
    }
  }

  @override
  void stopListening() {
    _timer?.cancel();
    _timer = null;
  }

  void _generateSample() {
    // 1. Simulate Natural Cadence Drift (Random Walk)
    final cadenceDrift =
        _random.nextDouble() * 2 * _cadenceDriftRange - _cadenceDriftRange;
    _currentCadence += cadenceDrift;
    _currentCadence =
        _currentCadence.clamp(_targetCadenceLow, _targetCadenceHigh);

    // Convert Cadence (SPM) to Frequency (Hz)
    final freqHz = _currentCadence / 60.0;

    // 2. Update Phase (phase accumulation to prevent floating point issues)
    _phase += 2 * pi * freqHz * _dt;
    _phase %= 2 * pi;

    // 3. Generate Waveform using accumulated phase
    final fundamental = sin(_phase);
    final harmonic =
        _harmonicCoefficient * sin(2 * _phase + _harmonicPhaseShift);

    // 4. Add Sensor/Movement Noise
    final noise = _nextGaussian() * _noiseStdDev;

    // 5. Combine components
    double acceleration = _gravityRemovedBaseline +
        (fundamental + harmonic) * (_impactMagnitude / 1.5) +
        noise;

    // 6. Rectify negatives slightly (as in Python simulation)
    if (acceleration < -3.0) {
      acceleration = acceleration * 0.5;
    }

    // Convert 1D acceleration to 3D accelerometer data
    // For realistic simulation, we assume phone is oriented such that
    // most of the running motion is in the z-axis (up/down) with
    // some smaller components in x and y axes
    final x = acceleration * 0.2 + _random.nextDouble() * 0.5 - 0.25;
    final y = acceleration * 0.1 + _random.nextDouble() * 0.3 - 0.15;
    final z = acceleration * 0.7 + _random.nextDouble() * 0.4 - 0.2;

    // Add device-specific gravity component (approx 9.8 m/s²)
    // Since we removed gravity baseline, we don't add it back

    final event = AccelerometerEvent(x, y, z, DateTime.now());
    _controller.add(event);
  }

  /// Clean up resources
  void dispose() {
    stopListening();
    _controller.close();
  }
}
