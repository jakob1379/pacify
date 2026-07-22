part of 'cadence_bloc.dart';

abstract class CadenceState extends Equatable {
  const CadenceState();

  @override
  List<Object> get props => [];
}

class CadenceInitial extends CadenceState {}

class CadenceLoading extends CadenceState {}

class CadenceLoaded extends CadenceState {
  /// AMDF valleys below this confidence are treated as no cadence.
  static const double minimumCadenceConfidence =
      AmdfProcessor.minimumConfidence;

  final double bpm;
  final double rawBpm;
  final double uncertainty;
  final double confidence;
  final List<double> timeSeriesData;

  /// Normalized inverted AMDF values, retained under the existing UI contract.
  final List<double> frequencySpectrum;

  /// Cadence bins in BPM, retained under the existing UI contract.
  final List<double> frequencyBins;
  final String currentState; // 'sampling' or 'paused'

  const CadenceLoaded(
    this.bpm, {
    this.rawBpm = 0,
    this.uncertainty = 5,
    this.confidence = 0,
    this.timeSeriesData = const [],
    this.frequencySpectrum = const [],
    this.frequencyBins = const [],
    this.currentState = 'sampling',
  });

  bool get hasReliableCadence =>
      bpm > 0 && confidence >= minimumCadenceConfidence;

  @override
  List<Object> get props => [
        bpm,
        rawBpm,
        uncertainty,
        confidence,
        timeSeriesData,
        frequencySpectrum,
        frequencyBins,
        currentState,
      ];
}

class CadenceError extends CadenceState {
  final String message;

  const CadenceError(this.message);

  @override
  List<Object> get props => [message];
}
