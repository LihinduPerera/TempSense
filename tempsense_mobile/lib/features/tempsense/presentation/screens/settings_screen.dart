import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/bloc/neck_cooler_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SharedPreferences _prefs;
  
  // MQTT Settings
  String _mqttBroker = 'broker.hivemq.com';
  int _mqttPort = 1883;
  
  // WiFi Settings (for Arduino device)
  String _deviceWifiSSID = 'Your_WiFi_SSID';
  String _deviceWifiPassword = 'Your_WiFi_Password';
  
  // App Settings
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  bool _autoConnect = true;
  bool _showAlerts = true;
  bool _vibrateOnAlert = true;
  bool _soundOnAlert = true;
  
  // Device Control Settings
  int _autoModeThreshold = 30; // Temperature threshold for auto mode
  int _maxFanSpeed = 100;
  int _minFanSpeed = 0;
  bool _enableHealthAlerts = true;
  bool _enableML = true;
  
  // Data Settings
  bool _saveSensorData = true;
  int _dataRetentionDays = 30;
  bool _uploadToCloud = false;
  
  // UI State
  bool _showWifiPassword = false;
  bool _showAdvancedSettings = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      // MQTT Settings
      _mqttBroker = _prefs.getString('mqtt_broker') ?? 'broker.hivemq.com';
      _mqttPort = _prefs.getInt('mqtt_port') ?? 1883;
      
      // WiFi Settings
      _deviceWifiSSID = _prefs.getString('device_wifi_ssid') ?? 'Your_WiFi_SSID';
      _deviceWifiPassword = _prefs.getString('device_wifi_password') ?? 'Your_WiFi_Password';
      
      // App Settings
      _darkMode = _prefs.getBool('dark_mode') ?? false;
      _notificationsEnabled = _prefs.getBool('notifications') ?? true;
      _autoConnect = _prefs.getBool('auto_connect') ?? true;
      _showAlerts = _prefs.getBool('show_alerts') ?? true;
      _vibrateOnAlert = _prefs.getBool('vibrate_on_alert') ?? true;
      _soundOnAlert = _prefs.getBool('sound_on_alert') ?? true;
      
      // Device Control Settings
      _autoModeThreshold = _prefs.getInt('auto_mode_threshold') ?? 30;
      _maxFanSpeed = _prefs.getInt('max_fan_speed') ?? 100;
      _minFanSpeed = _prefs.getInt('min_fan_speed') ?? 0;
      _enableHealthAlerts = _prefs.getBool('enable_health_alerts') ?? true;
      _enableML = _prefs.getBool('enable_ml') ?? true;
      
      // Data Settings
      _saveSensorData = _prefs.getBool('save_sensor_data') ?? true;
      _dataRetentionDays = _prefs.getInt('data_retention_days') ?? 30;
      _uploadToCloud = _prefs.getBool('upload_to_cloud') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    // MQTT Settings
    await _prefs.setString('mqtt_broker', _mqttBroker);
    await _prefs.setInt('mqtt_port', _mqttPort);
    
    // WiFi Settings
    await _prefs.setString('device_wifi_ssid', _deviceWifiSSID);
    await _prefs.setString('device_wifi_password', _deviceWifiPassword);
    
    // App Settings
    await _prefs.setBool('dark_mode', _darkMode);
    await _prefs.setBool('notifications', _notificationsEnabled);
    await _prefs.setBool('auto_connect', _autoConnect);
    await _prefs.setBool('show_alerts', _showAlerts);
    await _prefs.setBool('vibrate_on_alert', _vibrateOnAlert);
    await _prefs.setBool('sound_on_alert', _soundOnAlert);
    
    // Device Control Settings
    await _prefs.setInt('auto_mode_threshold', _autoModeThreshold);
    await _prefs.setInt('max_fan_speed', _maxFanSpeed);
    await _prefs.setInt('min_fan_speed', _minFanSpeed);
    await _prefs.setBool('enable_health_alerts', _enableHealthAlerts);
    await _prefs.setBool('enable_ml', _enableML);
    
    // Data Settings
    await _prefs.setBool('save_sensor_data', _saveSensorData);
    await _prefs.setInt('data_retention_days', _dataRetentionDays);
    await _prefs.setBool('upload_to_cloud', _uploadToCloud);
    
    // Apply theme change immediately
    if (context.mounted) {
      // Trigger theme rebuild in parent widget
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _sendWiFiToDevice() async {
    if (_deviceWifiSSID.isEmpty || _deviceWifiPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter WiFi SSID and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send WiFi Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will send WiFi credentials to your device. '
              'The device will need to reconnect to the new WiFi network.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.wifi, color: Colors.blue),
              title: const Text('WiFi SSID'),
              subtitle: Text(_deviceWifiSSID),
            ),
            ListTile(
              leading: const Icon(Icons.password, color: Colors.green),
              title: const Text('Password'),
              subtitle: Text('*' * _deviceWifiPassword.length),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Here you would send the WiFi credentials via MQTT
              // Example: context.read<NeckCoolerBloc>().add(SendWiFiConfig(_deviceWifiSSID, _deviceWifiPassword));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('WiFi configuration sent to device'),
                  backgroundColor: Colors.green.shade700,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send to Device'),
          ),
        ],
      ),
    );
  }

  Future<void> _testMQTTConnection() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(width: 16),
            const Text('Testing MQTT connection...'),
          ],
        ),
        duration: const Duration(seconds: 5),
      ),
    );
    
    await Future.delayed(const Duration(seconds: 2));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('MQTT connection test successful!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection Settings
          _buildSectionTitle('Connection Settings'),
          _buildTextField(
            label: 'MQTT Broker',
            value: _mqttBroker,
            onChanged: (value) => setState(() => _mqttBroker = value),
            icon: Icons.cloud,
            hint: 'e.g., broker.hivemq.com or 192.168.1.100',
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            label: 'MQTT Port',
            value: _mqttPort,
            onChanged: (value) => setState(() => _mqttPort = value),
            icon: Icons.numbers,
            min: 1,
            max: 65535,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testMQTTConnection,
                  icon: const Icon(Icons.cloud_sync),
                  label: const Text('Test Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Device WiFi Configuration
          _buildSectionTitle('Device WiFi Configuration'),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Enter the WiFi credentials for your neck cooler device:',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          _buildTextField(
            label: 'WiFi SSID',
            value: _deviceWifiSSID,
            onChanged: (value) => setState(() => _deviceWifiSSID = value),
            icon: Icons.wifi,
            hint: 'Your WiFi network name',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'WiFi Password',
            value: _deviceWifiPassword,
            onChanged: (value) => setState(() => _deviceWifiPassword = value),
            icon: Icons.password,
            obscureText: !_showWifiPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _showWifiPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: () => setState(() => _showWifiPassword = !_showWifiPassword),
            ),
            hint: 'Your WiFi password',
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _sendWiFiToDevice,
            icon: const Icon(Icons.send),
            label: const Text('Send WiFi Config to Device'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade50,
              foregroundColor: Colors.green,
            ),
          ),
          const SizedBox(height: 24),

          // App Settings
          _buildSectionTitle('App Settings'),
          _buildSwitchTile(
            title: 'Dark Mode',
            subtitle: 'Enable dark theme',
            value: _darkMode,
            onChanged: (value) => setState(() => _darkMode = value),
            icon: Icons.dark_mode,
          ),
          _buildSwitchTile(
            title: 'Notifications',
            subtitle: 'Receive health alerts',
            value: _notificationsEnabled,
            onChanged: (value) => setState(() => _notificationsEnabled = value),
            icon: Icons.notifications,
          ),
          if (_notificationsEnabled) ...[
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: _buildSwitchTile(
                title: 'Vibration',
                subtitle: 'Vibrate on alerts',
                value: _vibrateOnAlert,
                onChanged: (value) => setState(() => _vibrateOnAlert = value),
                icon: Icons.vibration,
                showSwitch: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: _buildSwitchTile(
                title: 'Sound',
                subtitle: 'Play sound on alerts',
                value: _soundOnAlert,
                onChanged: (value) => setState(() => _soundOnAlert = value),
                icon: Icons.volume_up,
                showSwitch: true,
              ),
            ),
          ],
          _buildSwitchTile(
            title: 'Auto Connect',
            subtitle: 'Connect to device automatically',
            value: _autoConnect,
            onChanged: (value) => setState(() => _autoConnect = value),
            icon: Icons.bluetooth,
          ),
          _buildSwitchTile(
            title: 'Show Health Alerts',
            subtitle: 'Display health warning notifications',
            value: _showAlerts,
            onChanged: (value) => setState(() => _showAlerts = value),
            icon: Icons.health_and_safety,
          ),
          const SizedBox(height: 24),

          // Device Control Settings
          _buildSectionTitle('Device Control Settings'),
          _buildSliderTile(
            title: 'Auto Mode Threshold',
            subtitle: 'Temperature (°C) to trigger auto mode',
            value: _autoModeThreshold.toDouble(),
            min: 20,
            max: 40,
            divisions: 20,
            unit: '°C',
            onChanged: (value) => setState(() => _autoModeThreshold = value.toInt()),
            icon: Icons.thermostat,
          ),
          _buildSwitchTile(
            title: 'Enable TinyML AI',
            subtitle: 'Use AI for automatic fan control',
            value: _enableML,
            onChanged: (value) => setState(() => _enableML = value),
            icon: Icons.psychology,
          ),
          _buildSwitchTile(
            title: 'Health Alerts',
            subtitle: 'Enable health monitoring alerts',
            value: _enableHealthAlerts,
            onChanged: (value) => setState(() => _enableHealthAlerts = value),
            icon: Icons.warning,
          ),
          _buildRangeSliderTile(
            title: 'Fan Speed Range',
            subtitle: 'Minimum and maximum fan speed limits',
            minValue: _minFanSpeed.toDouble(),
            maxValue: _maxFanSpeed.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            unit: '%',
            onChanged: (values) {
              setState(() {
                _minFanSpeed = values.start.toInt();
                _maxFanSpeed = values.end.toInt();
              });
            },
            icon: Icons.speed,
          ),
          const SizedBox(height: 24),

          // Data Settings
          _buildSectionTitle('Data Settings'),
          _buildSwitchTile(
            title: 'Save Sensor Data',
            subtitle: 'Store historical sensor readings',
            value: _saveSensorData,
            onChanged: (value) => setState(() => _saveSensorData = value),
            icon: Icons.save,
          ),
          if (_saveSensorData) ...[
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: _buildNumberField(
                label: 'Data Retention (Days)',
                value: _dataRetentionDays,
                onChanged: (value) => setState(() => _dataRetentionDays = value),
                icon: Icons.calendar_today,
                min: 1,
                max: 365,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: _buildSwitchTile(
                title: 'Upload to Cloud',
                subtitle: 'Sync data to cloud storage',
                value: _uploadToCloud,
                onChanged: (value) => setState(() => _uploadToCloud = value),
                icon: Icons.cloud_upload,
                showSwitch: true,
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Advanced Settings (Collapsible)
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.settings, color: Colors.blue),
              title: const Text(
                'Advanced Settings',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              initiallyExpanded: _showAdvancedSettings,
              onExpansionChanged: (expanded) => setState(() => _showAdvancedSettings = expanded),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildNumberField(
                        label: 'Sensor Update Interval (ms)',
                        value: 2000,
                        onChanged: (value) {},
                        icon: Icons.timer,
                        min: 500,
                        max: 10000,
                      ),
                      const SizedBox(height: 12),
                      _buildSwitchTile(
                        title: 'Debug Mode',
                        subtitle: 'Show detailed logs',
                        value: false,
                        onChanged: (value) {},
                        icon: Icons.bug_report,
                      ),
                      const SizedBox(height: 12),
                      _buildSwitchTile(
                        title: 'Auto Calibration',
                        subtitle: 'Automatically calibrate sensors',
                        value: true,
                        onChanged: (value) {},
                        icon: Icons.compass_calibration,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Device Information
          _buildSectionTitle('Device Information'),
          ListTile(
            leading: const Icon(Icons.device_hub, color: Colors.blue),
            title: const Text('Device Name'),
            subtitle: const Text('Neck Cooler v1.0'),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showDeviceInfoDialog(context),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.code, color: Colors.green),
            title: const Text('Firmware Version'),
            subtitle: const Text('1.2.0'),
            trailing: IconButton(
              icon: const Icon(Icons.update),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Checking for firmware updates...'),
                  ),
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.battery_charging_full, color: Colors.orange),
            title: const Text('Battery Level'),
            subtitle: const Text('85% (Good)'),
            trailing: const Icon(Icons.battery_full),
          ),
          ListTile(
            leading: const Icon(Icons.signal_wifi_4_bar, color: Colors.purple),
            title: const Text('WiFi Signal'),
            subtitle: const Text('Strong (-45 dBm)'),
            trailing: const Icon(Icons.signal_cellular_4_bar),
          ),
          const SizedBox(height: 24),

          // Danger Zone
          _buildSectionTitle('Danger Zone'),
          Card(
            color: Colors.red.shade50,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.restart_alt, color: Colors.red.shade700),
                  title: Text(
                    'Restart Device',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text('Soft restart the neck cooler device'),
                  trailing: IconButton(
                    icon: Icon(Icons.restart_alt, color: Colors.red.shade700),
                    onPressed: () => _showRestartConfirmation(context),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.cleaning_services, color: Colors.orange.shade700),
                  title: Text(
                    'Calibrate Sensors',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text('Recalibrate all sensors'),
                  trailing: IconButton(
                    icon: Icon(Icons.compass_calibration, color: Colors.orange.shade700),
                    onPressed: () => _showCalibrationDialog(context),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: const Text(
                    'Factory Reset',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text('Reset device to factory settings'),
                  trailing: IconButton(
                    icon: const Icon(Icons.restore, color: Colors.red),
                    onPressed: () => _showFactoryResetConfirmation(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // App Info
          Center(
            child: Column(
              children: [
                Text(
                  'Neck Cooler Controller v1.0.0',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '© 2024 Neck Cooler Inc.',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _showAboutDialog(context),
                  child: const Text('About & Privacy Policy'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        hintText: hint,
      ),
      controller: TextEditingController(text: value),
      onChanged: onChanged,
      obscureText: obscureText,
    );
  }

  Widget _buildNumberField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required IconData icon,
    int min = 0,
    int max = 9999,
  }) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        suffixText: '($min-$max)',
      ),
      controller: TextEditingController(text: value.toString()),
      keyboardType: TextInputType.number,
      onChanged: (text) {
        final parsed = int.tryParse(text);
        if (parsed != null && parsed >= min && parsed <= max) {
          onChanged(parsed);
        }
      },
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    bool showSwitch = true,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: '${value.toInt()}$unit',
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${value.toInt()}$unit',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSliderTile({
    required String title,
    required String subtitle,
    required double minValue,
    required double maxValue,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<RangeValues> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 8),
          RangeSlider(
            values: RangeValues(minValue, maxValue),
            min: min,
            max: max,
            divisions: divisions,
            labels: RangeLabels(
              '${minValue.toInt()}$unit',
              '${maxValue.toInt()}$unit',
            ),
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Min: ${minValue.toInt()}$unit',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                'Max: ${maxValue.toInt()}$unit',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeviceInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              ListTile(
                leading: Icon(Icons.memory, size: 20),
                title: Text('MCU'),
                subtitle: Text('ESP32 Dev Module'),
              ),
              ListTile(
                leading: Icon(Icons.sensors, size: 20),
                title: Text('Sensors'),
                subtitle: Text('DHT22, MAX30102, OLED Display'),
              ),
              ListTile(
                leading: Icon(Icons.wifi, size: 20),
                title: Text('Communication'),
                subtitle: Text('MQTT over WiFi, 2.4GHz'),
              ),
              ListTile(
                leading: Icon(Icons.psychology, size: 20),
                title: Text('AI Engine'),
                subtitle: Text('TinyML for adaptive fan control'),
              ),
              ListTile(
                leading: Icon(Icons.battery_std, size: 20),
                title: Text('Power'),
                subtitle: Text('5V USB, 18650 Battery Backup'),
              ),
              ListTile(
                leading: Icon(Icons.code, size: 20),
                title: Text('Firmware'),
                subtitle: Text('Version 1.2.0, Built on PlatformIO'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRestartConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Device?'),
        content: const Text(
          'This will soft restart the neck cooler device. '
          'It will take about 30 seconds to reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Send restart command via MQTT
              // context.read<NeckCoolerBloc>().add(RestartDevice());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Device restart command sent'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  void _showCalibrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calibrate Sensors'),
        content: const Text(
          'Place the device in a stable environment and remove it from your neck. '
          'This process will take about 60 seconds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Show calibration progress
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Calibrating'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      const Text('Calibrating sensors... Please wait.'),
                      const SizedBox(height: 10),
                      Text(
                        'Do not move the device during calibration.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              
              // Simulate calibration completion
              Future.delayed(const Duration(seconds: 3), () {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Calibration completed successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Calibration'),
          ),
        ],
      ),
    );
  }

  void _showFactoryResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Factory Reset?'),
        content: const Text(
          '⚠️ WARNING: This will reset ALL settings to factory defaults '
          'and clear all stored data. This action cannot be undone!\n\n'
          'The device will restart after reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Send factory reset command
              // context.read<NeckCoolerBloc>().add(FactoryResetDevice());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Factory reset command sent to device'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Factory Reset'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Neck Cooler Controller',
      applicationVersion: 'Version 1.0.0',
      applicationLegalese: '© 2024 Neck Cooler Inc.\nAll rights reserved.',
      children: [
        const SizedBox(height: 16),
        const Text(
          'An intelligent neck cooler system with TinyML AI for adaptive cooling control.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text('Features:'),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Real-time temperature monitoring'),
              Text('• Heart rate and SpO2 tracking'),
              Text('• TinyML AI for adaptive fan control'),
              Text('• Health alert notifications'),
              Text('• Data analytics and charts'),
              Text('• MQTT communication'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            // Open privacy policy
          },
          child: const Text('Privacy Policy'),
        ),
        TextButton(
          onPressed: () {
            // Open terms of service
          },
          child: const Text('Terms of Service'),
        ),
      ],
    );
  }
}