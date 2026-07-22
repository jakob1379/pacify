import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pacify/features/cadence_detector/data/services/sensor_service.dart';
import 'package:pacify/features/cadence_detector/presentation/bloc/cadence_bloc.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  test('stationary sensor noise is not sent to the Kalman filter', () async {
    final sensor = _FakeSensorService();
    final bloc = CadenceBloc(sensorService: sensor);
    addTearDown(() async {
      await bloc.close();
      await sensor.close();
    });

    await _start(bloc);
    expect(sensor.startListeningCalled, isTrue);
    final loaded = _nextLoaded(bloc);
    final random = Random(42);
    _emitSamples(
      sensor,
      (_) => 9.81 + (random.nextDouble() - 0.5) * 0.04,
    );
    final state = await loaded;

    expect(state.bpm, 0);
    expect(state.rawBpm, 0);
    expect(state.confidence, lessThan(CadenceLoaded.minimumCadenceConfidence));
    expect(state.uncertainty, 5);
    expect(state.hasReliableCadence, isFalse);
  });

  test('periodic movement updates the filter with the AMDF estimate', () async {
    final sensor = _FakeSensorService();
    final bloc = CadenceBloc(sensorService: sensor);
    addTearDown(() async {
      await bloc.close();
      await sensor.close();
    });

    await _start(bloc);
    expect(sensor.startListeningCalled, isTrue);
    final loaded = _nextLoaded(bloc);
    _emitSamples(
      sensor,
      (index) => 9.81 + 2 * sin(2 * pi * 180 / 60 * index * 0.025),
      interval: const Duration(milliseconds: 25),
    );
    final state = await loaded;

    expect(state.rawBpm, closeTo(180, 2));
    expect(state.bpm, greaterThan(150));
    expect(state.bpm, lessThan(state.rawBpm));
    expect(
        state.confidence, greaterThan(CadenceLoaded.minimumCadenceConfidence));
    expect(state.hasReliableCadence, isTrue);
    expect(state.currentState, 'paused');
  });
}

Future<void> _start(CadenceBloc bloc) async {
  final loading = bloc.stream.firstWhere((state) => state is CadenceLoading);
  bloc.add(StartCadenceDetection());
  await loading;
}

Future<CadenceLoaded> _nextLoaded(CadenceBloc bloc) => bloc.stream
    .firstWhere((state) => state is CadenceLoaded)
    .then((state) => state as CadenceLoaded)
    .timeout(const Duration(seconds: 2));

void _emitSamples(
  _FakeSensorService sensor,
  double Function(int index) xAt, {
  Duration interval = const Duration(milliseconds: 20),
}) {
  final start = DateTime.utc(2026);
  for (var index = 0; index < windowSize; index++) {
    sensor.add(
      AccelerometerEvent(
        xAt(index),
        0,
        0,
        start.add(Duration(microseconds: interval.inMicroseconds * index)),
      ),
    );
  }
}

class _FakeSensorService implements SensorService {
  var startListeningCalled = false;

  final _controller = StreamController<AccelerometerEvent>.broadcast(
    sync: true,
  );

  @override
  Stream<AccelerometerEvent> get accelerometerStream => _controller.stream;

  void add(AccelerometerEvent event) => _controller.add(event);

  Future<void> close() => _controller.close();

  @override
  Future<void> startListening() async {
    startListeningCalled = true;
  }

  @override
  void stopListening() {}
}
