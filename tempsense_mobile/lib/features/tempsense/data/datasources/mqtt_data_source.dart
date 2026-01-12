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
  
  // OPTIMIZED: Debounce timer to batch updates
  Timer? _updateTimer;
  bool _hasPendingUpdate = false;
  
  Stream<SensorData> get sensorStream => _sensorController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      _client = MqttServerClient(MQTTConfig.broker, MQTTConfig.generateClientId());
      _client.port = MQTTConfig.port;
      _client.keepAlivePeriod = 15;  // OPTIMIZED: Reduced for faster reconnection
      _client.onDisconnected = _onDisconnected;
      _client.logging(on: false);
      
      // OPTIMIZED: Shorter connection timeout
      _client.connectTimeoutPeriod = 5000;  // 5 seconds instead of default 30
      
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_client.clientIdentifier!)
          .startClean()
          .withWillTopic('willtopic')
          .withWillMessage('Will message')
          .withWillRetain()
          .withWillQos(MqttQos.atMostOnce);  // OPTIMIZED: QoS 0 for faster delivery
      
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
    // OPTIMIZED: Use QoS 0 for all topics - faster, no acknowledgment overhead
    for (final topic in MQTTConfig.topics.values) {
      _client.subscribe(topic, MqttQos.atMostOnce);
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
      bool needsUpdate = false;
      
      if (topic == MQTTConfig.topics['temperature']) {
        final newTemp = double.tryParse(data) ?? 0.0;
        if ((_currentData.temperature - newTemp).abs() > 0.1) {
          _currentData = _currentData.copyWith(
            temperature: newTemp,
            timestamp: DateTime.now(),
          );
          needsUpdate = true;
        }
      } else if (topic == MQTTConfig.topics['humidity']) {
        final newHumidity = double.tryParse(data) ?? 0.0;
        if ((_currentData.humidity - newHumidity).abs() > 0.1) {
          _currentData = _currentData.copyWith(
            humidity: newHumidity,
            timestamp: DateTime.now(),
          );
          needsUpdate = true;
        }
      } else if (topic == MQTTConfig.topics['heartRate']) {
        final newHR = int.tryParse(data) ?? 0;
        if (_currentData.heartRate != newHR) {
          _currentData = _currentData.copyWith(
            heartRate: newHR,
            timestamp: DateTime.now(),
          );
          needsUpdate = true;
        }
      } else if (topic == MQTTConfig.topics['spo2']) {
        final newSpO2 = int.tryParse(data) ?? 0;
        if (_currentData.spo2 != newSpO2) {
          _currentData = _currentData.copyWith(
            spo2: newSpO2,
            timestamp: DateTime.now(),
          );
          needsUpdate = true;
        }
      } else if (topic == MQTTConfig.topics['fanSpeed']) {
        final newSpeed = int.tryParse(data) ?? 0;
        // OPTIMIZED: Always update fan speed immediately for responsive UI
        _currentData = _currentData.copyWith(
          fanSpeed: newSpeed,
          timestamp: DateTime.now(),
        );
        // OPTIMIZED: Emit immediately for fan speed changes
        _sensorController.add(_currentData.copyWith(isConnected: true));
        return;  // Skip debouncing for fan speed
      } else if (topic == MQTTConfig.topics['mlStatus']) {
        final newConfidence = double.tryParse(data) ?? 0.0;
        if ((_currentData.mlConfidence - newConfidence).abs() > 0.01) {
          _currentData = _currentData.copyWith(
            mlConfidence: newConfidence,
            timestamp: DateTime.now(),
          );
          needsUpdate = true;
        }
      }

      // OPTIMIZED: Debounce other sensor updates to reduce UI rebuilds
      if (needsUpdate) {
        _hasPendingUpdate = true;
        _updateTimer?.cancel();
        _updateTimer = Timer(const Duration(milliseconds: 100), () {
          if (_hasPendingUpdate) {
            _sensorController.add(_currentData.copyWith(isConnected: true));
            _hasPendingUpdate = false;
          }
        });
      }

    } catch (e) {
      print('Error processing message: $e');
    }
  }

  Future<void> setFanSpeed(int speed) async {
    if (!_isConnected) return;
    
    // OPTIMIZED: Update local state immediately for UI responsiveness
    _currentData = _currentData.copyWith(
      fanSpeed: speed,
      autoMode: false,
    );
    _sensorController.add(_currentData.copyWith(isConnected: true));
    
    // Then send to device with QoS 0 for speed
    final builder = MqttClientPayloadBuilder();
    builder.addString(speed.toString());
    
    _client.publishMessage(
      MQTTConfig.topics['control']!,
      MqttQos.atMostOnce,  // OPTIMIZED: QoS 0 for fastest delivery
      builder.payload!,
      retain: false,  // Don't retain control messages
    );
  }

  Future<void> setAutoMode(bool autoMode) async {
    if (!_isConnected) return;
    
    // OPTIMIZED: Update local state immediately
    _currentData = _currentData.copyWith(autoMode: autoMode);
    _sensorController.add(_currentData.copyWith(isConnected: true));
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(autoMode ? 'AUTO' : 'MANUAL');
    
    _client.publishMessage(
      MQTTConfig.topics['control']!,
      MqttQos.atMostOnce,  // OPTIMIZED: QoS 0 for fastest delivery
      builder.payload!,
      retain: false,
    );
  }

  void _onDisconnected() {
    _isConnected = false;
    _updateTimer?.cancel();
    _sensorController.add(_currentData.copyWith(isConnected: false));
  }

  Future<void> disconnect() async {
    _updateTimer?.cancel();
    _client.disconnect();
    _isConnected = false;
    await _sensorController.close();
  }
}