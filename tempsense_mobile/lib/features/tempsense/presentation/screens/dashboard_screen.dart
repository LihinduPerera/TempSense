import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tempsense_mobile/core/theme/app_theme.dart';
import 'package:tempsense_mobile/features/tempsense/domain/entities/sensor_data.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/bloc/neck_cooler_bloc.dart';
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neck Cooler Controller'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh connection
              context.read<NeckCoolerBloc>().add(ConnectToDevice());
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: BlocConsumer<NeckCoolerBloc, NeckCoolerState>(
        listener: (context, state) {
          if (state is NeckCoolerError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is NeckCoolerInitial) {
            return _buildInitialView(context);
          } else if (state is NeckCoolerLoading) {
            return _buildLoadingView();
          } else if (state is NeckCoolerError) {
            return _buildErrorView(context, state);
          } else if (state is NeckCoolerConnected) {
            return _buildConnectedView(context, state);
          }
          return _buildInitialView(context);
        },
      ),
    );
  }

  Widget _buildInitialView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.device_hub,
            size: 120,
            color: AppTheme.primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Neck Cooler Controller',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Connect to your IoT Neck Cooler device to start monitoring and controlling.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 40),
          ConnectionStatus(
            isConnected: false,
            onConnect: () {
              context.read<NeckCoolerBloc>().add(ConnectToDevice());
            },
            onDisconnect: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 20),
          Text(
            'Connecting to device...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, NeckCoolerError state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 24),
          Text(
            'Connection Error',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          ConnectionStatus(
            isConnected: false,
            onConnect: () {
              context.read<NeckCoolerBloc>().add(ConnectToDevice());
            },
            onDisconnect: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedView(BuildContext context, NeckCoolerConnected state) {
    final data = state.data;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ConnectionStatus(
            isConnected: data.isConnected,
            onConnect: () {
              context.read<NeckCoolerBloc>().add(ConnectToDevice());
            },
            onDisconnect: () {
              context.read<NeckCoolerBloc>().add(DisconnectFromDevice());
            },
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
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
                icon: Icons.water_drop,
                color: Colors.blue,
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
            ],
          ),
          const SizedBox(height: 16),
          FanControlCard(
            fanSpeed: data.fanSpeed,
            autoMode: state.isAutoMode,
            isConnected: data.isConnected,
          ),
          const SizedBox(height: 16),
          MLStatusCard(
            mlConfidence: data.mlConfidence,
            autoMode: state.isAutoMode,
          ),
          const SizedBox(height: 20),
          _buildAlertsSection(data),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(SensorData data) {
    final alerts = <String>[];
    
    if (data.temperature > 35) {
      alerts.add('High temperature detected! (${
        data.temperature.toStringAsFixed(1)}°C)');
    }
    if (data.humidity > 70) {
      alerts.add('High humidity may affect cooling efficiency');
    }
    if (data.heartRate > 100) {
      alerts.add('Elevated heart rate detected');
    }
    if (data.spo2 < 95) {
      alerts.add('SpO₂ level is lower than normal');
    }
    
    if (alerts.isEmpty) return const SizedBox();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.withOpacity(0.3)),
      ),
      color: Colors.orange.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Health Alerts',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...alerts.map((alert) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.circle,
                    size: 6,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _getTemperatureColor(double temperature) {
    if (temperature < 28) return Colors.blue;
    if (temperature < 32) return Colors.green;
    if (temperature < 36) return Colors.orange;
    return Colors.red;
  }
}