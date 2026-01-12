import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/bloc/neck_cooler_bloc.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  int _selectedChart = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Analytics'),
        centerTitle: true,
      ),
      body: BlocBuilder<NeckCoolerBloc, NeckCoolerState>(
        builder: (context, state) {
          if (state is! NeckCoolerConnected) {
            return Center(
              child: Text(
                'Connect to device to view charts',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            );
          }

          final data = state.data;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Temperature'),
                      icon: Icon(Icons.thermostat),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Heart Rate'),
                      icon: Icon(Icons.favorite),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('Fan Speed'),
                      icon: Icon(Icons.speed),
                    ),
                  ],
                  selected: {_selectedChart},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() {
                      _selectedChart = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: _buildChart(_selectedChart, data),
                ),
                const SizedBox(height: 20),
                _buildStatsCards(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChart(int chartType, dynamic data) {
    // Mock historical data for demonstration
    final List<ChartData> chartData = [
      ChartData('10:00', 28.0, 75, 30),
      ChartData('10:30', 29.5, 78, 45),
      ChartData('11:00', 31.0, 82, 60),
      ChartData('11:30', 32.5, 85, 75),
      ChartData('12:00', 33.0, 88, 80),
      ChartData('12:30', 31.5, 85, 70),
      ChartData('13:00', 30.0, 80, 55),
    ];

    switch (chartType) {
      case 0:
        return SfCartesianChart(
          title: const ChartTitle(text: 'Temperature Trend'),
          primaryXAxis: const CategoryAxis(),
          primaryYAxis: const NumericAxis(
            title: AxisTitle(text: 'Temperature (°C)'),
            minimum: 20,
            maximum: 40,
          ),
          series: <CartesianSeries<ChartData, String>>[
            LineSeries<ChartData, String>(
              dataSource: chartData,
              xValueMapper: (ChartData data, _) => data.time,
              yValueMapper: (ChartData data, _) => data.temperature,
              markerSettings: const MarkerSettings(isVisible: true),
              dataLabelSettings: const DataLabelSettings(isVisible: true),
            ),
          ],
        );
      case 1:
        return SfCartesianChart(
          title: const ChartTitle(text: 'Heart Rate Trend'),
          primaryXAxis: const CategoryAxis(),
          primaryYAxis: const NumericAxis(
            title: AxisTitle(text: 'Heart Rate (BPM)'),
            minimum: 60,
            maximum: 100,
          ),
          series: <CartesianSeries<ChartData, String>>[
            LineSeries<ChartData, String>(
              dataSource: chartData,
              xValueMapper: (ChartData data, _) => data.time,
              yValueMapper: (ChartData data, _) => data.heartRate,
              markerSettings: const MarkerSettings(isVisible: true),
              color: Colors.red,
            ),
          ],
        );
      case 2:
        return SfCartesianChart(
          title: const ChartTitle(text: 'Fan Speed Trend'),
          primaryXAxis: const CategoryAxis(),
          primaryYAxis: const NumericAxis(
            title: AxisTitle(text: 'Fan Speed (%)'),
            minimum: 0,
            maximum: 100,
          ),
          series: <CartesianSeries<ChartData, String>>[
            ColumnSeries<ChartData, String>(
              dataSource: chartData,
              xValueMapper: (ChartData data, _) => data.time,
              yValueMapper: (ChartData data, _) => data.fanSpeed,
              dataLabelSettings: const DataLabelSettings(isVisible: true),
              color: Colors.blue,
            ),
          ],
        );
      default:
        return Container();
    }
  }

  Widget _buildStatsCards(dynamic data) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildStatCard(
          'Avg Temp',
          '${(28.5).toStringAsFixed(1)}°C',
          Icons.thermostat,
          Colors.orange,
        ),
        _buildStatCard(
          'Avg HR',
          '${(80).toStringAsFixed(0)} BPM',
          Icons.favorite,
          Colors.red,
        ),
        _buildStatCard(
          'Max Speed',
          '${(85).toStringAsFixed(0)}%',
          Icons.speed,
          Colors.blue,
        ),
        _buildStatCard(
          'AI Accuracy',
          '${(data.mlConfidence * 100).toStringAsFixed(0)}%',
          Icons.psychology,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartData {
  final String time;
  final double temperature;
  final int heartRate;
  final int fanSpeed;

  ChartData(this.time, this.temperature, this.heartRate, this.fanSpeed);
}