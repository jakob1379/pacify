import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fftea/fftea.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pacify/features/cadence_detector/data/services/sensor_service.dart';
import 'package:pacify/features/cadence_detector/data/utils/kalman_filter.dart';
import 'package:sensors_plus/sensors_plus.dart';

part 'cadence_event.dart';
part 'cadence_state.dart';

const int sampleRate = 50;
const int windowSize = 256; // ~5 seconds of data
const int stepSize = 50; // Process every second (50 samples)
const double minFrequencyHz = 1.0; // Minimum cadence frequency (60 SPM)
const double maxFrequencyHz = 5.0; // Maximum cadence frequency (300 SPM)
const double minBPM = 60.0;
const double maxBPM = 300.0;
const double samplingDurationSeconds = 5.0;
const double pauseDurationSeconds = 15.0;

class CadenceBloc extends Bloc<CadenceEvent, CadenceState> {
  final SensorService sensorService;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final List<double> _accelerometerData = [];
  Timer? _timer;
  late final KalmanFilter _kalmanFilter;
  late final int _minFrequencyIndex;
  late final int _maxFrequencyIndex;
  String _currentState = 'sampling';
  DateTime _lastStateChange = DateTime.now();
  double _lastBpm = 150.0;

  CadenceBloc({required this.sensorService}) : super(CadenceInitial()) {
    print('CadenceBloc constructor');
    // Compute frequency indices for 1-5 Hz range
    _minFrequencyIndex = (minFrequencyHz * windowSize / sampleRate).ceil();
    _maxFrequencyIndex = (maxFrequencyHz * windowSize / sampleRate).floor();
    // Ensure indices are within valid range (1 to windowSize/2 - 1)
    if (_minFrequencyIndex < 1) _minFrequencyIndex = 1;
    if (_maxFrequencyIndex > windowSize ~/ 2) _maxFrequencyIndex = windowSize ~/ 2;
    
    // Initialize Kalman filter with initial estimate 150 BPM, large uncertainty
    _kalmanFilter = KalmanFilter(
      initialEstimate: 150.0,
      initialError: 100.0,
      processNoise: 0.1,
      measurementNoise: 10.0,
    );
    
    on<StartCadenceDetection>(_onStartCadenceDetection);
    on<StopCadenceDetection>(_onStopCadenceDetection);
    on<_NewAccelerometerData>(_onNewAccelerometerData);
  }

  void _onStartCadenceDetection(
      StartCadenceDetection event, Emitter<CadenceState> emit) {
    if (Platform.isAndroid) {
      FlutterForegroundTask.startService(
        notificationTitle: 'Cadence Detection Active',
        notificationText: 'Tap to return to the app',
        callback: () {
          _startListening();
        },
      );
    } else {
      _startListening();
    }
    emit(CadenceLoading());
  }

  void _onStopCadenceDetection(
      StopCadenceDetection event, Emitter<CadenceState> emit) {
    _stopListening();
    if (Platform.isAndroid) {
      FlutterForegroundTask.stopService();
    }
    emit(CadenceInitial());
  }

  void _startListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription =
        sensorService.accelerometerStream.listen((data) {
      add(_NewAccelerometerData(data));
    });
  }

  void _stopListening() {
    _accelerometerSubscription?.cancel();
    _timer?.cancel();
  }

  void _updateState() {
    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastStateChange).inSeconds.toDouble();

    if (_currentState == 'sampling' && elapsedSeconds > samplingDurationSeconds) {
      // Switch to paused
      _currentState = 'paused';
      _lastStateChange = now;
      // Clear accelerometer data as in Python simulation
      _accelerometerData.clear();
    } else if (_currentState == 'paused' && elapsedSeconds > pauseDurationSeconds) {
      // Switch back to sampling
      _currentState = 'sampling';
      _lastStateChange = now;
    }
  }

  void _onNewAccelerometerData(
      _NewAccelerometerData event, Emitter<CadenceState> emit) {
    _updateState();
    
    if (_currentState == 'paused') {
      // Emit paused state with last BPM and empty visualization
      emit(CadenceLoaded(
        _lastBpm,
        timeSeriesData: const [],
        frequencySpectrum: const [],
        frequencyBins: const [],
        currentState: 'paused',
      ));
      return;
    }
    
    final magnitude =
        sqrt(pow(event.data.x, 2) + pow(event.data.y, 2) + pow(event.data.z, 2));
    _accelerometerData.add(magnitude);

    if (_accelerometerData.length >= windowSize) {
      final stft = STFT(windowSize, Window.hanning(windowSize));
      stft.run(Float64List.fromList(_accelerometerData), (spectogram) {
        final frequencies = spectogram;

        // Find the dominant frequency within cadence range
        var dominantFrequencyIndex = 0;
        var maxAmplitude = 0.0;
        for (var i = _minFrequencyIndex; i <= _maxFrequencyIndex; i++) {
          if (i >= frequencies.length) break;
          final amplitude = sqrt(pow(frequencies[i].x, 2) + pow(frequencies[i].y, 2));
          if (amplitude > maxAmplitude) {
            maxAmplitude = amplitude;
            dominantFrequencyIndex = i;
          }
        }

        // If no dominant frequency found (should not happen), fallback to first index
        if (dominantFrequencyIndex == 0) {
          dominantFrequencyIndex = _minFrequencyIndex;
        }

        final dominantFrequency =
            dominantFrequencyIndex * sampleRate / windowSize;
        final bpm = dominantFrequency * 60;

        // Apply Kalman filter for smoothing
        final filteredBpm = _kalmanFilter.update(bpm);
        final clampedBpm = filteredBpm.clamp(minBPM, maxBPM);
        _lastBpm = clampedBpm;

        // Prepare visualization data
        final timeSeriesData = List<double>.from(_accelerometerData);
        
        // Compute frequency spectrum up to 10 Hz (like Python simulation)
        const double maxVizFrequencyHz = 10.0;
        final maxVizIndex = (maxVizFrequencyHz * windowSize / sampleRate).floor();
        final effectiveMaxIndex = maxVizIndex.clamp(0, frequencies.length - 1);
        
        final frequencyBins = <double>[];
        final frequencySpectrum = <double>[];
        
        for (var i = 0; i <= effectiveMaxIndex; i++) {
          final freqHz = i * sampleRate / windowSize;
          final amplitude = sqrt(pow(frequencies[i].x, 2) + pow(frequencies[i].y, 2));
          frequencyBins.add(freqHz);
          frequencySpectrum.add(amplitude);
        }
        
        emit(CadenceLoaded(
          clampedBpm,
          timeSeriesData: timeSeriesData,
          frequencySpectrum: frequencySpectrum,
          frequencyBins: frequencyBins,
          currentState: _currentState,
        ));

        // Keep sliding window: remove oldest stepSize samples
        if (_accelerometerData.length > stepSize) {
          _accelerometerData.removeRange(0, stepSize);
        } else {
          _accelerometerData.clear();
        }
      });
    }
  }

  @override
  Future<void> close() {
    _stopListening();
    FlutterForegroundTask.stopService();
    return super.close();
  }
}
