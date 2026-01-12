import 'dart:async';

import 'package:tempsense_mobile/features/tempsense/data/datasources/mqtt_data_source.dart';
import 'package:tempsense_mobile/features/tempsense/domain/entities/sensor_data.dart';
import 'package:tempsense_mobile/features/tempsense/domain/repositories/neck_cooler_repository.dart';


class NeckCoolerRepositoryImpl implements NeckCoolerRepository {
  final MQTTDataSource _mqttDataSource;

  NeckCoolerRepositoryImpl(this._mqttDataSource);

  @override
  Future<void> connect() async {
    await _mqttDataSource.connect();
  }

  @override
  Future<void> disconnect() async {
    await _mqttDataSource.disconnect();
  }

  @override
  Stream<SensorData> get sensorStream => _mqttDataSource.sensorStream;

  @override
  Future<void> setFanSpeed(int speed) async {
    await _mqttDataSource.setFanSpeed(speed);
  }

  @override
  Future<void> setAutoMode(bool autoMode) async {
    await _mqttDataSource.setAutoMode(autoMode);
  }

  @override
  bool get isConnected => _mqttDataSource.isConnected;
}