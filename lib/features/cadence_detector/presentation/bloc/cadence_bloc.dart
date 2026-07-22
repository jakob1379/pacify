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

const int windowSize = 256;
const double pauseDurationSeconds = 15;

class CadenceBloc extends Bloc<CadenceEvent, CadenceState> {
  CadenceBloc({required this.sensorService}) : super(CadenceInitial()) {
    on<CadenceEvent>(
      _onCadenceEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  final SensorService sensorService;
  final ScalarKalmanFilter _kalmanFilter = ScalarKalmanFilter();
  final List<double> _accelerometerData = [];

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime? _firstSampleTimestamp;
  String _samplingPhase = 'sampling';
  DateTime _lastPhaseChange = DateTime.now();
  double _lastBpm = 0;
  double _lastRawBpm = 0;
  double _lastConfidence = 0;
  bool _hasReliableCadence = false;
  List<double> _lastAmdfSimilarities = const [];
  List<double> _lastBpmBins = const [];

  Future<void> _onCadenceEvent(
    CadenceEvent event,
    Emitter<CadenceState> emit,
  ) async {
    if (event is StartCadenceDetection) {
      await _onStartCadenceDetection(event, emit);
    } else if (event is StopCadenceDetection) {
      await _onStopCadenceDetection(event, emit);
    } else if (event is _NewAccelerometerData) {
      _onNewAccelerometerData(event, emit);
    }
  }

  Future<void> _onStartCadenceDetection(
    StartCadenceDetection event,
    Emitter<CadenceState> emit,
  ) async {
    _resetDetection();
    try {
      await _startListening();
    } catch (_) {
      emit(const CadenceError('Unable to start cadence detection'));
      return;
    }
    if (Platform.isAndroid) {
      FlutterForegroundTask.startService(
        notificationTitle: 'Cadence Detection Active',
        notificationText: 'Tap to return to the app',
      );
    }
    emit(CadenceLoading());
  }

  Future<void> _onStopCadenceDetection(
    StopCadenceDetection event,
    Emitter<CadenceState> emit,
  ) async {
    await _stopListening();
    if (Platform.isAndroid) FlutterForegroundTask.stopService();
    emit(CadenceInitial());
  }

  void _resetDetection() {
    _samplingPhase = 'sampling';
    _lastPhaseChange = DateTime.now();
    _accelerometerData.clear();
    _firstSampleTimestamp = null;
    _lastBpm = 0;
    _lastRawBpm = 0;
    _lastConfidence = 0;
    _hasReliableCadence = false;
    _lastAmdfSimilarities = const [];
    _lastBpmBins = const [];
    _kalmanFilter.reset();
  }

  Future<void> _startListening() async {
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = sensorService.accelerometerStream.listen(
      (data) => add(_NewAccelerometerData(data)),
    );
    try {
      await sensorService.startListening();
    } catch (_) {
      await _accelerometerSubscription?.cancel();
      _accelerometerSubscription = null;
      rethrow;
    }
  }

  Future<void> _stopListening() async {
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    sensorService.stopListening();
  }

  bool _resumeSamplingIfDue(DateTime sampleTimestamp) {
    if (_samplingPhase != 'paused') return false;

    final elapsedSeconds =
        sampleTimestamp.difference(_lastPhaseChange).inMicroseconds /
            Duration.microsecondsPerSecond;

    if (elapsedSeconds >= pauseDurationSeconds) {
      _samplingPhase = 'sampling';
      _lastPhaseChange = sampleTimestamp;
      _accelerometerData.clear();
      _firstSampleTimestamp = null;
      _lastAmdfSimilarities = const [];
      _lastBpmBins = const [];
      return true;
    }
    return false;
  }

  void _onNewAccelerometerData(
    _NewAccelerometerData event,
    Emitter<CadenceState> emit,
  ) {
    final data = event.data;
    if (_resumeSamplingIfDue(data.timestamp)) emit(_loadedState());
    if (_samplingPhase == 'paused') {
      emit(_loadedState());
      return;
    }

    _firstSampleTimestamp ??= data.timestamp;
    _accelerometerData.add(
      sqrt(data.x * data.x + data.y * data.y + data.z * data.z),
    );
    if (_accelerometerData.length < windowSize) return;

    final processor = AmdfProcessor(_effectiveSampleRate(data.timestamp));
    final result = processor.analyze(_accelerometerData);
    final visualization = processor.visualizationData(result.values);
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
    _lastPhaseChange = data.timestamp;
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

  double _effectiveSampleRate(DateTime lastTimestamp) {
    final firstTimestamp = _firstSampleTimestamp;
    if (firstTimestamp == null || _accelerometerData.length < 2) {
      return SensorService.samplingRate.toDouble();
    }

    final elapsedMicroseconds =
        lastTimestamp.difference(firstTimestamp).inMicroseconds;
    if (elapsedMicroseconds <= 0) return SensorService.samplingRate.toDouble();
    return (_accelerometerData.length - 1) *
        Duration.microsecondsPerSecond /
        elapsedMicroseconds;
  }

  @override
  Future<void> close() async {
    await _stopListening();
    if (Platform.isAndroid) FlutterForegroundTask.stopService();
    return super.close();
  }
}
