import 'package:equatable/equatable.dart';

class SensorData extends Equatable {
  final double temperature;
  final double humidity;
  final int heartRate;
  final int spo2;
  final int fanSpeed;
  final double mlConfidence;
  final bool autoMode;
  final DateTime timestamp;
  final bool isConnected;

  const SensorData({
    required this.temperature,
    required this.humidity,
    required this.heartRate,
    required this.spo2,
    required this.fanSpeed,
    required this.mlConfidence,
    required this.autoMode,
    required this.timestamp,
    required this.isConnected,
  });

  SensorData copyWith({
    double? temperature,
    double? humidity,
    int? heartRate,
    int? spo2,
    int? fanSpeed,
    double? mlConfidence,
    bool? autoMode,
    DateTime? timestamp,
    bool? isConnected,
  }) {
    return SensorData(
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      heartRate: heartRate ?? this.heartRate,
      spo2: spo2 ?? this.spo2,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      mlConfidence: mlConfidence ?? this.mlConfidence,
      autoMode: autoMode ?? this.autoMode,
      timestamp: timestamp ?? this.timestamp,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  // Change from getter to static method
  static SensorData empty() {
    return SensorData(
      temperature: 0.0,
      humidity: 0.0,
      heartRate: 0,
      spo2: 0,
      fanSpeed: 0,
      mlConfidence: 0.0,
      autoMode: true,
      timestamp: DateTime.now(),
      isConnected: false,
    );
  }

  @override
  List<Object?> get props => [
        temperature,
        humidity,
        heartRate,
        spo2,
        fanSpeed,
        mlConfidence,
        autoMode,
        timestamp,
        isConnected,
      ];
}