/// Simple 1D Kalman filter for scalar values.
class KalmanFilter {
  /// Current state estimate
  double _x;
  
  /// Current estimate error covariance
  double _p;
  
  /// Process noise covariance (how much we expect the true state to change)
  final double _q;
  
  /// Measurement noise covariance (how much we trust the measurements)
  final double _r;
  
  /// Kalman gain (computed each update)
  double _k = 0.0;
  
  /// Constructor with initial estimate and noise parameters.
  /// [initialEstimate]: initial state value
  /// [initialError]: initial error variance (uncertainty)
  /// [processNoise]: process noise covariance (Q)
  /// [measurementNoise]: measurement noise covariance (R)
  KalmanFilter({
    required double initialEstimate,
    required double initialError,
    required double processNoise,
    required double measurementNoise,
  })  : _x = initialEstimate,
        _p = initialError,
        _q = processNoise,
        _r = measurementNoise;
  
  /// Update the filter with a new measurement.
  /// Returns the filtered estimate.
  double update(double measurement) {
    // Prediction update (state and covariance)
    // For constant velocity model, we assume state doesn't change (x = x)
    // But we increase uncertainty by process noise
    _p = _p + _q;
    
    // Measurement update
    _k = _p / (_p + _r); // Kalman gain
    _x = _x + _k * (measurement - _x);
    _p = (1 - _k) * _p;
    
    return _x;
  }
  
  /// Get current estimate.
  double get estimate => _x;
  
  /// Reset filter with new initial values.
  void reset({
    required double initialEstimate,
    required double initialError,
  }) {
    _x = initialEstimate;
    _p = initialError;
    _k = 0.0;
  }
}
