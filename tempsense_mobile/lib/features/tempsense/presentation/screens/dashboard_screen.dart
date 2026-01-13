import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tempsense_mobile/core/notifications/notification_service.dart';
import 'package:tempsense_mobile/core/theme/app_theme.dart';
import 'package:tempsense_mobile/core/utils/heat_index_utils.dart';
import 'package:tempsense_mobile/features/tempsense/domain/entities/sensor_data.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/bloc/neck_cooler_bloc.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/screens/charts_screen.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/screens/location_screen.dart'; // NEW
import 'package:tempsense_mobile/features/tempsense/presentation/screens/settings_screen.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/widgets/connection_status.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/widgets/fan_control_card.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/widgets/ml_status_card.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/widgets/sensor_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SensorData? _previousData;
  double? _previousHeatIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('TempSense'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<NeckCoolerBloc>().add(const ConnectToDevice());
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChartsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.map), // NEW: Map button
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: BlocConsumer<NeckCoolerBloc, NeckCoolerState>(
        listener: (context, state) {
          // Existing error snackbar
          if (state is NeckCoolerError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }

          // NEW: Notification logic when thresholds are crossed
          if (state is NeckCoolerConnected) {
            final data = state.data;
            final heatIndex = calculateHeatIndex(data.temperature, data.humidity);

            // Individual sensor alerts
            if (data.temperature > 35 && (_previousData?.temperature ?? 0) <= 35) {
              NotificationService().showNotification(
                id: 1,
                title: 'High Temperature',
                body: 'Temperature exceeded 35°C (${data.temperature.toStringAsFixed(1)}°C)',
              );
            }
            if (data.humidity > 70 && (_previousData?.humidity ?? 0) <= 70) {
              NotificationService().showNotification(
                id: 2,
                title: 'High Humidity',
                body: 'Humidity is over 70% (${data.humidity.toStringAsFixed(0)}%)',
              );
            }
            if (data.heartRate > 100 && (_previousData?.heartRate ?? 0) <= 100) {
              NotificationService().showNotification(
                id: 3,
                title: 'Elevated Heart Rate',
                body: 'Heart rate is ${data.heartRate} BPM',
              );
            }
            if (data.spo2 < 95 && (_previousData?.spo2 ?? 100) >= 95) {
              NotificationService().showNotification(
                id: 4,
                title: 'Low SpO₂',
                body: 'SpO₂ level dropped to ${data.spo2}%',
              );
            }

            // Heat Index danger alert (only when entering a higher risk level)
            final currentRisk = getHeatIndexRiskLevel(heatIndex);
            final previousRisk = getHeatIndexRiskLevel(_previousHeatIndex ?? 0);
            if ((currentRisk == 'Danger' || currentRisk == 'Extreme Danger') &&
                (previousRisk != 'Danger' && previousRisk != 'Extreme Danger')) {
              NotificationService().showNotification(
                id: 5,
                title: '$currentRisk - Heat Alert',
                body: 'Heat Index: ${heatIndex.toStringAsFixed(1)}°C — Take immediate action!',
              );
            }

            // Update previous values
            _previousData = data.copyWith();
            _previousHeatIndex = heatIndex;
          }
        },
        builder: (context, state) {
          if (state is NeckCoolerInitial) {
            return _buildGradientBackground(isDark, _buildInitialView(context));
          } else if (state is NeckCoolerLoading) {
            return _buildGradientBackground(isDark, _buildLoadingView());
          } else if (state is NeckCoolerError) {
            return _buildGradientBackground(isDark, _buildErrorView(context, state));
          } else if (state is NeckCoolerConnected) {
            return _buildGradientBackground(isDark, _buildConnectedView(context, state));
          }
          return _buildGradientBackground(isDark, _buildInitialView(context));
        },
      ),
    );
  }

  Widget _buildGradientBackground(bool isDark, Widget child) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
      ? [const Color(0xFF002925), const Color(0xFF001A17)] // Subtle dark teal tint
      : [const Color(0xFFE0F2F1), Colors.white], // Teal 50 → white (softer and matches theme)
        ),
      ),
      child: child,
    );
  }

  Widget _buildInitialView(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Icon(
              Icons.device_thermostat,
              size: 120,
              color: AppTheme.primaryColor.withOpacity(0.4),
            ),
            const SizedBox(height: 32),
            Text(
              'TempSense',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connect to your TempSense device to start monitoring and controlling.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 60),
            ConnectionStatus(
              isConnected: false,
              onConnect: () {
                context.read<NeckCoolerBloc>().add(const ConnectToDevice());
              },
              onDisconnect: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            const SizedBox(height: 24),
            Text(
              'Connecting to device...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, NeckCoolerError state) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Icon(Icons.error_outline, size: 100, color: Colors.red[400]),
            const SizedBox(height: 32),
            Text(
              'Connection Error',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.red[400],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 40),
            ConnectionStatus(
              isConnected: false,
              onConnect: () {
                context.read<NeckCoolerBloc>().add(const ConnectToDevice());
              },
              onDisconnect: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedView(BuildContext context, NeckCoolerConnected state) {
    final data = state.data;
    final heatIndex = calculateHeatIndex(data.temperature, data.humidity);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            ConnectionStatus(
              isConnected: data.isConnected,
              onConnect: () => context.read<NeckCoolerBloc>().add(const ConnectToDevice()),
              onDisconnect: () => context.read<NeckCoolerBloc>().add(const DisconnectFromDevice()),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
              children: [
                SensorCard(
                  icon: Icons.thermostat,
                  color: Colors.orange,
                  title: 'Temperature',
                  value: data.temperature.toStringAsFixed(1),
                  unit: '°C',
                  valueColor: _getTemperatureColor(data.temperature),
                ),
                SensorCard(
                  icon: Icons.opacity,
                  color: Colors.cyan,
                  title: 'Humidity',
                  value: data.humidity.toStringAsFixed(0),
                  unit: '%',
                ),
                SensorCard(
                  icon: Icons.favorite,
                  color: Colors.red,
                  title: 'Heart Rate',
                  value: data.heartRate.toString(),
                  unit: 'BPM',
                ),
                SensorCard(
                  icon: Icons.bloodtype,
                  color: Colors.green,
                  title: 'SpO₂',
                  value: data.spo2.toString(),
                  unit: '%',
                ),
                // NEW: Heat Index card
                SensorCard(
                  icon: Icons.wb_sunny,
                  color: getHeatIndexColor(heatIndex),
                  title: 'Heat Index',
                  value: heatIndex.toStringAsFixed(1),
                  unit: '°C',
                  valueColor: getHeatIndexColor(heatIndex),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FanControlCard(
              fanSpeed: data.fanSpeed,
              autoMode: state.isAutoMode,
              isConnected: data.isConnected,
            ),
            const SizedBox(height: 24),
            MLStatusCard(
              mlConfidence: data.mlConfidence,
              autoMode: state.isAutoMode,
            ),
            const SizedBox(height: 32),
            _buildAlertsSection(data, heatIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection(SensorData data, double heatIndex) {
    final alerts = <String>[];

    if (data.temperature > 35) alerts.add('High temperature detected! (${data.temperature.toStringAsFixed(1)}°C)');
    if (data.humidity > 70) alerts.add('High humidity detected (${data.humidity.toStringAsFixed(0)}%)');
    if (data.heartRate > 100) alerts.add('Elevated heart rate (${data.heartRate} BPM)');
    if (data.spo2 < 95) alerts.add('Low SpO₂ level (${data.spo2}%)');

    // Heat Index alerts
    final risk = getHeatIndexRiskLevel(heatIndex);
    if (risk == 'Extreme Danger') {
      alerts.add('EXTREME DANGER: Heat Index ${heatIndex.toStringAsFixed(1)}°C');
    } else if (risk == 'Danger') {
      alerts.add('DANGER: Heat Index ${heatIndex.toStringAsFixed(1)}°C');
    } else if (risk == 'Extreme Caution') {
      alerts.add('Extreme Caution: Heat Index ${heatIndex.toStringAsFixed(1)}°C');
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.orange.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Text(
                  'Health & Heat Alerts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...alerts.map((alert) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(child: Text(alert, style: TextStyle(color: Colors.orange[800]))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Color _getTemperatureColor(double temperature) {
    if (temperature < 28) return Colors.cyan;
    if (temperature < 32) return Colors.green;
    if (temperature < 36) return Colors.orange;
    return Colors.red;
  }
}