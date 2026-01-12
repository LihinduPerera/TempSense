import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:tempsense_mobile/features/tempsense/domain/entities/sensor_data.dart';
import 'package:tempsense_mobile/shared/utils/mqtt_config.dart';

class MQTTDataSource {
  late MqttServerClient _client;
  final StreamController<SensorData> _sensorController = StreamController<SensorData>.broadcast();
  
  bool _isConnected = false;
  SensorData _currentData = SensorData.empty();
  
  Stream<SensorData> get sensorStream => _sensorController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      _client = MqttServerClient(MQTTConfig.broker, MQTTConfig.generateClientId());
      _client.port = MQTTConfig.port;
      _client.keepAlivePeriod = 60;
      _client.onDisconnected = _onDisconnected;
      _client.logging(on: false);
      
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_client.clientIdentifier!)
          .startClean()
          .withWillTopic('willtopic')
          .withWillMessage('Will message')
          .withWillRetain()
          .withWillQos(MqttQos.atLeastOnce);
      
      _client.connectionMessage = connMessage;
      
      await _client.connect();
      
      if (_client.connectionStatus?.state == MqttConnectionState.connected) {
        _isConnected = true;
        _subscribeToTopics();
        _listenForMessages();
      } else {
        throw Exception('Failed to connect to MQTT broker');
      }
    } catch (e) {
      _isConnected = false;
      rethrow;
    }
  }

  void _subscribeToTopics() {
    for (final topic in MQTTConfig.topics.values) {
      _client.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  void _listenForMessages() {
    _client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final message in messages) {
        final topic = message.topic;
        final payload = message.payload as MqttPublishMessage;
        final data = MqttPublishPayload.bytesToStringAsString(payload.payload.message);
        
        _processMessage(topic, data);
      }
    });
  }

  void _processMessage(String topic, String data) {
  try {
    // Use if-else instead of switch-case for non-constant patterns
    if (topic == MQTTConfig.topics['temperature']) {
      _currentData = _currentData.copyWith(
        temperature: double.tryParse(data) ?? 0.0,
        timestamp: DateTime.now(),
      );
    } else if (topic == MQTTConfig.topics['humidity']) {
      _currentData = _currentData.copyWith(
        humidity: double.tryParse(data) ?? 0.0,
        timestamp: DateTime.now(),
      );
    } else if (topic == MQTTConfig.topics['heartRate']) {
      _currentData = _currentData.copyWith(
        heartRate: int.tryParse(data) ?? 0,
        timestamp: DateTime.now(),
      );
    } else if (topic == MQTTConfig.topics['spo2']) {
      _currentData = _currentData.copyWith(
        spo2: int.tryParse(data) ?? 0,
        timestamp: DateTime.now(),
      );
    } else if (topic == MQTTConfig.topics['fanSpeed']) {
      _currentData = _currentData.copyWith(
        fanSpeed: int.tryParse(data) ?? 0,
        timestamp: DateTime.now(),
      );
    } else if (topic == MQTTConfig.topics['mlStatus']) {
      _currentData = _currentData.copyWith(
        mlConfidence: double.tryParse(data) ?? 0.0,
        timestamp: DateTime.now(),
      );
    }

    // Emit updated data
    _sensorController.add(_currentData.copyWith(isConnected: true));

  } catch (e) {
    print('Error processing message: $e');
  }
}

  Future<void> setFanSpeed(int speed) async {
    if (!_isConnected) return;
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(speed.toString());
    
    _client.publishMessage(
      MQTTConfig.topics['control']!,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    
    // Also switch to manual mode
    _currentData = _currentData.copyWith(autoMode: false);
  }

  Future<void> setAutoMode(bool autoMode) async {
    if (!_isConnected) return;
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(autoMode ? 'AUTO' : 'MANUAL');
    
    _client.publishMessage(
      MQTTConfig.topics['control']!,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    
    _currentData = _currentData.copyWith(autoMode: autoMode);
  }

  void _onDisconnected() {
    _isConnected = false;
    _sensorController.add(_currentData.copyWith(isConnected: false));
  }

  Future<void> disconnect() async {
    // await _client.disconnect();
     _client.disconnect();
    _isConnected = false;
    _sensorController.close();
  }
}