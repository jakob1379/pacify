class AmdfResult {
  const AmdfResult({
    required this.bpm,
    required this.confidence,
    required this.bestLag,
    required this.values,
  });

  final double bpm;
  final double confidence;
  final int bestLag;
  final Map<int, double> values;
}

/// Estimates cadence with the Average Magnitude Difference Function (AMDF).
///
/// AMDF compares a signal with lagged copies of itself. Periodic motion creates
/// a valley at its period; parabolic interpolation around that valley provides
/// a fractional lag before conversion to beats per minute.
class AmdfProcessor {
  AmdfProcessor(this.sampleRate) : assert(sampleRate > 0);

  static const double minBpm = 120;
  static const double maxBpm = 240;
  static const double minimumConfidence = 0.1;

  final double sampleRate;

  AmdfResult analyze(List<double> samples) {
    final values = computeAmdfValues(samples);
    final bestLag = findBestLag(values);
    if (bestLag == 0) {
      return AmdfResult(bpm: 0, confidence: 0, bestLag: 0, values: values);
    }

    final preciseLag = _interpolateLag(values, bestLag);
    final bpm = (sampleRate * 60 / preciseLag).clamp(minBpm, maxBpm);
    return AmdfResult(
      bpm: bpm,
      confidence: calculateConfidence(values, bestLag),
      bestLag: bestLag,
      values: values,
    );
  }

  /// Computes mean absolute differences for the cadence lag range.
  ///
  /// One supporting lag is included on either side so estimates at 120 and
  /// 240 BPM can still use three-point interpolation.
  Map<int, double> computeAmdfValues(List<double> samples) {
    if (samples.length < 3) return const {};

    final minCandidateLag = (sampleRate * 60 / maxBpm).floor();
    final maxCandidateLag = (sampleRate * 60 / minBpm).ceil();
    final firstLag = (minCandidateLag - 1).clamp(1, samples.length - 1);
    final lastLag = (maxCandidateLag + 1).clamp(1, samples.length - 1);
    if (firstLag > lastLag) return const {};

    final values = <int, double>{};
    for (var lag = firstLag; lag <= lastLag; lag++) {
      var difference = 0.0;
      final comparisons = samples.length - lag;
      for (var index = 0; index < comparisons; index++) {
        difference += (samples[index + lag] - samples[index]).abs();
      }
      values[lag] = difference / comparisons;
    }
    return values;
  }

  /// Returns the first AMDF valley whose nominal BPM overlaps the search range.
  ///
  /// Periodic signals also create valleys at integer multiples of their true
  /// period. Choosing the first local valley avoids reporting a 240 BPM signal
  /// as its 120 BPM subharmonic. The global minimum remains a fallback for
  /// irregular curves without a strict local minimum.
  int findBestLag(Map<int, double> values) {
    final minLag = (sampleRate * 60 / maxBpm).floor();
    final maxLag = (sampleRate * 60 / minBpm).ceil();
    final candidateLags = values.keys
        .where((lag) => lag >= minLag && lag <= maxLag)
        .toList()
      ..sort();

    for (final lag in candidateLags) {
      final left = values[lag - 1];
      final center = values[lag]!;
      final right = values[lag + 1];
      if (left != null && right != null && center <= left && center <= right) {
        return lag;
      }
    }

    if (candidateLags.isEmpty) return 0;
    return candidateLags.reduce(
      (best, lag) => values[lag]! < values[best]! ? lag : best,
    );
  }

  /// Scores valley prominence from 0 (flat/noisy) to 1 (strongly periodic).
  ///
  /// A useful cadence valley is substantially lower than the rest of the AMDF
  /// curve. Ratios at or above 0.5 are treated as noise; deeper valleys are
  /// scaled linearly into the 0-1 range.
  double calculateConfidence(Map<int, double> values, int bestLag) {
    if (values.length < 4 || !values.containsKey(bestLag)) return 0;

    var surroundingTotal = 0.0;
    var surroundingCount = 0;
    for (final entry in values.entries) {
      if ((entry.key - bestLag).abs() <= 1) continue;
      surroundingTotal += entry.value;
      surroundingCount++;
    }
    if (surroundingCount == 0) return 0;

    final surroundingMean = surroundingTotal / surroundingCount;
    if (surroundingMean <= 1e-12) return 0;

    final valleyRatio = values[bestLag]! / surroundingMean;
    return (1 - 2 * valleyRatio).clamp(0, 1);
  }

  /// Returns ascending BPM bins and normalized inverted AMDF values for debug
  /// visualization. Flat signals produce zeroes rather than artificial peaks.
  ({List<double> bpmBins, List<double> similarities}) visualizationData(
    Map<int, double> values,
  ) {
    final entries = values.entries
        .map(
          (entry) => (bpm: sampleRate * 60 / entry.key, value: entry.value),
        )
        .where((entry) => entry.bpm >= minBpm && entry.bpm <= maxBpm)
        .toList()
      ..sort((a, b) => a.bpm.compareTo(b.bpm));
    if (entries.isEmpty) return (bpmBins: const [], similarities: const []);

    final maximum = entries
        .map((entry) => entry.value)
        .reduce((left, right) => left > right ? left : right);
    return (
      bpmBins: entries.map((entry) => entry.bpm).toList(),
      similarities: maximum <= 1e-12
          ? List<double>.filled(entries.length, 0)
          : entries
              .map(
                (entry) => (1 - entry.value / maximum).clamp(0, 1).toDouble(),
              )
              .toList(),
    );
  }

  double _interpolateLag(Map<int, double> values, int bestLag) {
    final left = values[bestLag - 1];
    final center = values[bestLag];
    final right = values[bestLag + 1];
    if (left == null || center == null || right == null) {
      return bestLag.toDouble();
    }

    final denominator = left - 2 * center + right;
    if (denominator.abs() <= 1e-12) return bestLag.toDouble();

    final offset = (0.5 * (left - right) / denominator).clamp(-0.5, 0.5);
    return bestLag + offset;
  }
}
