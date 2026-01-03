part of 'cadence_bloc.dart';

abstract class CadenceState extends Equatable {
  const CadenceState();

  @override
  List<Object> get props => [];
}

class CadenceInitial extends CadenceState {}

class CadenceLoading extends CadenceState {}

class CadenceLoaded extends CadenceState {
  final double bpm;
  final List<double> timeSeriesData;
  final List<double> frequencySpectrum;
  final List<double> frequencyBins;
  final String currentState; // 'sampling' or 'paused'

  const CadenceLoaded(
    this.bpm, {
    this.timeSeriesData = const [],
    this.frequencySpectrum = const [],
    this.frequencyBins = const [],
    this.currentState = 'sampling',
  });

  @override
  List<Object> get props => [bpm, timeSeriesData, frequencySpectrum, frequencyBins, currentState];
}

class CadenceError extends CadenceState {
  final String message;

  const CadenceError(this.message);

  @override
  List<Object> get props => [message];
}
