class MQTTConfig {
  // Use HiveMQ public broker for testing
  static const String broker = 'broker.hivemq.com';
  static const int port = 1883;
  static const String clientId = 'flutter_neckcooler_';

  // Topics - MUST MATCH ARDUINO CODE
  static final Map<String, String> topics = {
    'temperature': 'neckcooler/sensors/temperature',
    'humidity': 'neckcooler/sensors/humidity',
    'heartRate': 'neckcooler/sensors/heartrate',
    'spo2': 'neckcooler/sensors/spo2',
    'fanSpeed': 'neckcooler/sensors/fan_speed',
    'mlStatus': 'neckcooler/ml/status',
    'control': 'neckcooler/control/fan_speed',
  };

  static String generateClientId() {
    return '${clientId}${DateTime.now().millisecondsSinceEpoch}';
  }
}