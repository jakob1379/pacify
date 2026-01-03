import 'package:sensors_plus/sensors_plus.dart';
import 'simulated_sensor_service.dart';

abstract class SensorService {
  Stream<AccelerometerEvent> get accelerometerStream;
  Future<void> startListening();
  void stopListening();
  
  /// Factory method to create appropriate sensor service
  /// [useSimulation] - if true, uses simulated data; if false, uses real device sensors
  static SensorService create({bool useSimulation = false}) {
    if (useSimulation) {
      return SimulatedSensorService();
    } else {
      return SensorServiceImpl();
    }
  }
}

class SensorServiceImpl implements SensorService {
  @override
  Stream<AccelerometerEvent> get accelerometerStream => accelerometerEventStream();

  @override
  Future<void> startListening() async {
    // The sensors_plus package starts listening automatically when subscribed to the stream.
    // No explicit start method is needed.
  }

  @override
  void stopListening() {
    // The stream subscription should be cancelled in the BLoC to stop listening.
  }
}
