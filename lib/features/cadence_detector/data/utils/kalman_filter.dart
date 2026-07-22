/// Time-aware scalar Kalman filter for cadence measurements.
///
/// The state model assumes cadence remains constant between samples while its
/// uncertainty grows by [processNoisePerSecond] for every elapsed second.
class ScalarKalmanFilter {
  ScalarKalmanFilter({
    double initialEstimate = 150,
    double initialUncertainty = 5,
    this.processNoisePerSecond = 0.5,
    this.measurementNoise = 2,
  })  : assert(initialUncertainty >= 0),
        assert(processNoisePerSecond >= 0),
        assert(measurementNoise > 0),
        _estimate = initialEstimate,
        _uncertainty = initialUncertainty;

  final double processNoisePerSecond;
  final double measurementNoise;

  double _estimate;
  double _uncertainty;
  DateTime? _lastObservation;

  double get estimate => _estimate;
  double get uncertainty => _uncertainty;

  /// Predicts uncertainty to [observedAt], then incorporates [measurement].
  double update(double measurement, {DateTime? observedAt}) {
    if (!measurement.isFinite) {
      throw ArgumentError.value(measurement, 'measurement', 'must be finite');
    }

    final observation = observedAt ?? DateTime.now();
    var elapsedSeconds = 0.0;
    if (_lastObservation != null && observation.isAfter(_lastObservation!)) {
      elapsedSeconds =
          observation.difference(_lastObservation!).inMicroseconds /
              Duration.microsecondsPerSecond;
    }
    if (_lastObservation == null || observation.isAfter(_lastObservation!)) {
      _lastObservation = observation;
    }

    _uncertainty += processNoisePerSecond * elapsedSeconds;
    final gain = _uncertainty / (_uncertainty + measurementNoise);
    _estimate += gain * (measurement - _estimate);
    _uncertainty *= 1 - gain;
    return _estimate;
  }

  void reset({double initialEstimate = 150, double initialUncertainty = 5}) {
    if (initialUncertainty < 0) {
      throw ArgumentError.value(
        initialUncertainty,
        'initialUncertainty',
        'must not be negative',
      );
    }
    _estimate = initialEstimate;
    _uncertainty = initialUncertainty;
    _lastObservation = null;
  }
}
