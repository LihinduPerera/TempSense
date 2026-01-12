import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SharedPreferences _prefs;

  // MQTT
  String _mqttBroker = 'broker.hivemq.com';
  int _mqttPort = 1883;

  // WiFi
  String _deviceWifiSSID = '';
  String _deviceWifiPassword = '';

  // App
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  bool _autoConnect = true;
  bool _showAlerts = true;

  // Device control
  int _autoModeThreshold = 30;
  bool _enableML = true;

  bool _showWifiPassword = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _mqttBroker = _prefs.getString('mqtt_broker') ?? 'broker.hivemq.com';
      _mqttPort = _prefs.getInt('mqtt_port') ?? 1883;
      _deviceWifiSSID = _prefs.getString('device_wifi_ssid') ?? '';
      _deviceWifiPassword = _prefs.getString('device_wifi_password') ?? '';
      _darkMode = _prefs.getBool('dark_mode') ?? false;
      _notificationsEnabled = _prefs.getBool('notifications') ?? true;
      _autoConnect = _prefs.getBool('auto_connect') ?? true;
      _showAlerts = _prefs.getBool('show_alerts') ?? true;
      _autoModeThreshold = _prefs.getInt('auto_mode_threshold') ?? 30;
      _enableML = _prefs.getBool('enable_ml') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    await _prefs.setString('mqtt_broker', _mqttBroker);
    await _prefs.setInt('mqtt_port', _mqttPort);
    await _prefs.setString('device_wifi_ssid', _deviceWifiSSID);
    await _prefs.setString('device_wifi_password', _deviceWifiPassword);
    await _prefs.setBool('dark_mode', _darkMode);
    await _prefs.setBool('notifications', _notificationsEnabled);
    await _prefs.setBool('auto_connect', _autoConnect);
    await _prefs.setBool('show_alerts', _showAlerts);
    await _prefs.setInt('auto_mode_threshold', _autoModeThreshold);
    await _prefs.setBool('enable_ml', _enableML);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Connection'),
          _textField('MQTT Broker', _mqttBroker, (v) => _mqttBroker = v, Icons.cloud),
          const SizedBox(height: 12),
          _numberField('MQTT Port', _mqttPort, (v) => _mqttPort = v),
          const SizedBox(height: 24),

          _sectionTitle('Device WiFi Setup'),
          _textField('WiFi SSID', _deviceWifiSSID, (v) => _deviceWifiSSID = v, Icons.wifi),
          const SizedBox(height: 12),
          _textField(
            'WiFi Password',
            _deviceWifiPassword,
            (v) => _deviceWifiPassword = v,
            Icons.lock,
            obscure: !_showWifiPassword,
            suffix: IconButton(
              icon: Icon(_showWifiPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showWifiPassword = !_showWifiPassword),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {}, // Implement send if needed
            icon: const Icon(Icons.send),
            label: const Text('Send to TempSense Device'),
          ),
          const SizedBox(height: 32),

          _sectionTitle('App Preferences'),
          _switchTile('Dark Mode', 'Use dark theme', _darkMode, (v) => setState(() => _darkMode = v), Icons.dark_mode),
          _switchTile('Notifications', 'Health alerts', _notificationsEnabled, (v) => setState(() => _notificationsEnabled = v), Icons.notifications),
          _switchTile('Auto Connect', 'Connect on launch', _autoConnect, (v) => setState(() => _autoConnect = v), Icons.bluetooth_connected),
          _switchTile('Show Alerts', 'In-app health warnings', _showAlerts, (v) => setState(() => _showAlerts = v), Icons.warning),

          const SizedBox(height: 32),
          _sectionTitle('Device Control'),
          _sliderTile('Auto Mode Threshold (°C)', _autoModeThreshold.toDouble(), 20, 40, (v) => setState(() => _autoModeThreshold = v.toInt())),
          _switchTile('Enable TinyML AI', 'AI-controlled cooling', _enableML, (v) => setState(() => _enableML = v), Icons.psychology),

          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Text('TempSense v1.0.0', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text('© 2026 TempSense', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _textField(String label, String value, ValueChanged<String> onChanged, IconData icon, {bool obscure = false, Widget? suffix}) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      controller: TextEditingController(text: value)..selection = TextSelection.fromPosition(TextPosition(offset: value.length)),
      onChanged: onChanged,
      obscureText: obscure,
    );
  }

  Widget _numberField(String label, int value, ValueChanged<int> onChanged) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.numbers),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      keyboardType: TextInputType.number,
      controller: TextEditingController(text: value.toString()),
      onChanged: (t) => onChanged(int.tryParse(t) ?? value),
    );
  }

  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged, IconData icon) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _sliderTile(String title, double value, double min, double max, ValueChanged<double> onChanged) {
    return ListTile(
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: (max - min).toInt(),
        label: value.toInt().toString(),
        onChanged: onChanged,
      ),
      trailing: Text('${value.toInt()}°C', style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}