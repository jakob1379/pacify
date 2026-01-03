part of 'cadence_bloc.dart';

abstract class CadenceEvent extends Equatable {
  const CadenceEvent();

  @override
  List<Object> get props => [];
}

class StartCadenceDetection extends CadenceEvent {}

class StopCadenceDetection extends CadenceEvent {}

class _NewAccelerometerData extends CadenceEvent {
  final AccelerometerEvent data;

  const _NewAccelerometerData(this.data);

  @override
  List<Object> get props => [data];
}
