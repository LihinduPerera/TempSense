

import 'package:tempsense_mobile/features/tempsense/domain/entities/sensor_data.dart';

abstract class NeckCoolerRepository {
  // Connection
  Future<void> connect();
  Future<void> disconnect();
  
  // Data Stream
  Stream<SensorData> get sensorStream;
  
  // Control
  Future<void> setFanSpeed(int speed);
  Future<void> setAutoMode(bool autoMode);
  
  // Status
  bool get isConnected;
}