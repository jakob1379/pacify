import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pacify/features/cadence_detector/data/utils/amdf_processor.dart';

void main() {
  const sampleRate = 50.0;
  final processor = AmdfProcessor(sampleRate);

  test('finds a periodic cadence with sub-sample interpolation', () {
    const targetBpm = 180.0;
    final samples = List<double>.generate(
      256,
      (index) => sin(2 * pi * targetBpm / 60 * index / sampleRate),
    );

    final result = processor.analyze(samples);

    expect(result.bpm, closeTo(targetBpm, 1));
    expect(result.confidence, greaterThan(0.8));
  });

  test('keeps interpolation accurate near the search boundaries', () {
    for (final targetBpm in [121.0, 235.0, 239.0]) {
      final samples = List<double>.generate(
        256,
        (index) => sin(2 * pi * targetBpm / 60 * index / sampleRate),
      );

      final result = processor.analyze(samples);

      expect(result.bpm, closeTo(targetBpm, 2), reason: '$targetBpm BPM');
    }
  });

  test('prefers the first valley over a lower subharmonic', () {
    final samples = List<double>.generate(
      256,
      (index) => sin(2 * pi * 240 / 60 * index / sampleRate),
    );

    expect(processor.analyze(samples).bestLag, lessThan(20));
  });

  test('assigns zero confidence to a stationary signal', () {
    final result = processor.analyze(List<double>.filled(256, 9.81));
    final visualization = processor.visualizationData(result.values);

    expect(result.confidence, 0);
    expect(visualization.similarities, everyElement(0));
  });

  test('rejects aperiodic stationary sensor noise', () {
    final random = Random(42);
    final samples = List<double>.generate(
      256,
      (_) => 9.81 + (random.nextDouble() - 0.5) * 0.04,
    );

    final result = processor.analyze(samples);

    expect(result.confidence, lessThan(AmdfProcessor.minimumConfidence));
  });

  test('keeps visualization bins ordered and inside cadence range', () {
    final samples = List<double>.generate(
      256,
      (index) => sin(2 * pi * 160 / 60 * index / sampleRate),
    );
    final visualization = processor.visualizationData(
      processor.analyze(samples).values,
    );

    expect(
      visualization.bpmBins,
      orderedEquals(visualization.bpmBins.toList()..sort()),
    );
    expect(
      visualization.bpmBins,
      everyElement(
        inInclusiveRange(AmdfProcessor.minBpm, AmdfProcessor.maxBpm),
      ),
    );
  });
}
