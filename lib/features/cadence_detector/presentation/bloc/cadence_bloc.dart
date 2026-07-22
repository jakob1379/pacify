import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pacify/features/cadence_detector/data/services/sensor_service.dart';
import 'package:pacify/features/cadence_detector/data/utils/amdf_processor.dart';
import 'package:pacify/features/cadence_detector/data/utils/kalman_filter.dart';
import 'package:sensors_plus/sensors_plus.dart';

part 'cadence_event.dart';
part 'cadence_state.dart';

const int sampleRate = 50;
const int windowSize = 256;
const double pauseDurationSeconds = 15;

class CadenceBloc extends Bloc<CadenceEvent, CadenceState> {
  CadenceBloc({required this.sensorService}) : super(CadenceInitial()) {
    on<StartCadenceDetection>(_onStartCadenceDetection);
    on<StopCadenceDetection>(_onStopCadenceDetection);
    on<_NewAccelerometerData>(_onNewAccelerometerData);
  }

  final SensorService sensorService;
  final AmdfProcessor _amdfProcessor = AmdfProcessor(sampleRate.toDouble());
  final ScalarKalmanFilter _kalmanFilter = ScalarKalmanFilter();
  final List<double> _accelerometerData = [];

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  String _samplingPhase = 'sampling';
  DateTime _lastPhaseChange = DateTime.now();
  double _lastBpm = 0;
  double _lastRawBpm = 0;
  double _lastConfidence = 0;
  bool _hasReliableCadence = false;
  List<double> _lastAmdfSimilarities = const [];
  List<double> _lastBpmBins = const [];

  void _onStartCadenceDetection(
    StartCadenceDetection event,
    Emitter<CadenceState> emit,
  ) {
    _resetDetection();
    _startListening();
    if (Platform.isAndroid) {
      FlutterForegroundTask.startService(
        notificationTitle: 'Cadence Detection Active',
        notificationText: 'Tap to return to the app',
      );
    }
    emit(CadenceLoading());
  }

  void _onStopCadenceDetection(
    StopCadenceDetection event,
    Emitter<CadenceState> emit,
  ) {
    _stopListening();
    if (Platform.isAndroid) FlutterForegroundTask.stopService();
    emit(CadenceInitial());
  }

  void _resetDetection() {
    _samplingPhase = 'sampling';
    _lastPhaseChange = DateTime.now();
    _accelerometerData.clear();
    _lastBpm = 0;
    _lastRawBpm = 0;
    _lastConfidence = 0;
    _hasReliableCadence = false;
    _lastAmdfSimilarities = const [];
    _lastBpmBins = const [];
    _kalmanFilter.reset();
  }

  void _startListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = sensorService.accelerometerStream.listen(
      (data) => add(_NewAccelerometerData(data)),
    );
  }

  void _stopListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  void _resumeSamplingIfDue() {
    if (_samplingPhase != 'paused') return;

    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastPhaseChange).inMicroseconds /
        Duration.microsecondsPerSecond;

    if (elapsedSeconds >= pauseDurationSeconds) {
      _samplingPhase = 'sampling';
      _lastPhaseChange = now;
      _accelerometerData.clear();
      _lastAmdfSimilarities = const [];
      _lastBpmBins = const [];
    }
  }

  void _onNewAccelerometerData(
    _NewAccelerometerData event,
    Emitter<CadenceState> emit,
  ) {
    _resumeSamplingIfDue();
    if (_samplingPhase == 'paused') {
      emit(_loadedState());
      return;
    }

    final data = event.data;
    _accelerometerData.add(
      sqrt(data.x * data.x + data.y * data.y + data.z * data.z),
    );
    if (_accelerometerData.length < windowSize) return;

    final result = _amdfProcessor.analyze(_accelerometerData);
    final visualization = _amdfProcessor.visualizationData(result.values);
    _lastAmdfSimilarities = visualization.similarities;
    _lastBpmBins = visualization.bpmBins;
    _lastConfidence = result.confidence;
    _hasReliableCadence =
        result.confidence >= CadenceLoaded.minimumCadenceConfidence;

    if (_hasReliableCadence) {
      _lastRawBpm = result.bpm;
      _lastBpm = _kalmanFilter.update(
        result.bpm,
        observedAt: event.data.timestamp,
      );
    } else {
      // A flat or noisy AMDF has no trustworthy period. Do not let its
      // arbitrary minimum update the Kalman state.
      _lastRawBpm = 0;
    }

    // A completed window ends the sampling burst. Keep its result visible
    // during the pause, then collect a fresh window on resume.
    _samplingPhase = 'paused';
    _lastPhaseChange = DateTime.now();
    emit(_loadedState());
  }

  CadenceLoaded _loadedState() => CadenceLoaded(
        _hasReliableCadence ? _lastBpm : 0,
        rawBpm: _hasReliableCadence ? _lastRawBpm : 0,
        uncertainty: _kalmanFilter.uncertainty,
        confidence: _lastConfidence,
        timeSeriesData: List<double>.from(_accelerometerData),
        frequencySpectrum: List<double>.from(_lastAmdfSimilarities),
        frequencyBins: List<double>.from(_lastBpmBins),
        currentState: _samplingPhase,
      );

  @override
  Future<void> close() {
    _stopListening();
    if (Platform.isAndroid) FlutterForegroundTask.stopService();
    return super.close();
  }
}
