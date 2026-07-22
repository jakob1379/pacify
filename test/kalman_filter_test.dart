import 'package:flutter_test/flutter_test.dart';
import 'package:pacify/features/cadence_detector/data/utils/kalman_filter.dart';

void main() {
  test('applies the scalar Kalman update equation', () {
    final filter = ScalarKalmanFilter();

    final estimate = filter.update(180, observedAt: DateTime.utc(2026));

    expect(estimate, closeTo(171.428571, 1e-6));
    expect(filter.uncertainty, closeTo(1.428571, 1e-6));
  });

  test('elapsed time increases the weight of a new observation', () {
    final immediate = ScalarKalmanFilter();
    final delayed = ScalarKalmanFilter();
    final start = DateTime.utc(2026);

    immediate.update(180, observedAt: start);
    delayed.update(180, observedAt: start);

    final immediateEstimate = immediate.update(200, observedAt: start);
    final delayedEstimate = delayed.update(
      200,
      observedAt: start.add(const Duration(milliseconds: 500)),
    );

    expect(delayedEstimate, greaterThan(immediateEstimate));
    expect(delayedEstimate, lessThan(200));
  });

  test('reset restores the initial state and covariance', () {
    final filter = ScalarKalmanFilter()..update(180);

    filter.reset(initialEstimate: 160, initialUncertainty: 3);

    expect(filter.estimate, 160);
    expect(filter.uncertainty, 3);
  });
}
