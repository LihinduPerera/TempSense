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
        title: const Text('Analytics'),
        centerTitle: true,
      ),
      body: BlocBuilder<NeckCoolerBloc, NeckCoolerState>(
        builder: (context, state) {
          if (state is! NeckCoolerConnected) {
            return Center(
              child: Text(
                'Connect to device to view analytics',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
              ),
            );
          }

          final data = state.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Temperature'), icon: Icon(Icons.thermostat)),
                    ButtonSegment(value: 1, label: Text('Heart Rate'), icon: Icon(Icons.favorite)),
                    ButtonSegment(value: 2, label: Text('Fan Speed'), icon: Icon(Icons.speed)),
                  ],
                  selected: {_selectedChart},
                  onSelectionChanged: (set) => setState(() => _selectedChart = set.first),
                ),
                const SizedBox(height: 32),
                SizedBox(height: 320, child: _buildChart(_selectedChart)),
                const SizedBox(height: 32),
                _buildStatsCards(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChart(int type) {
    final List<ChartData> chartData = [
      ChartData('10:00', 28.0, 75, 30),
      ChartData('10:30', 29.5, 78, 45),
      ChartData('11:00', 31.0, 82, 60),
      ChartData('11:30', 32.5, 85, 75),
      ChartData('12:00', 33.0, 88, 80),
      ChartData('12:30', 31.5, 85, 70),
      ChartData('13:00', 30.0, 80, 55),
    ];

    switch (type) {
      case 0:
        return SfCartesianChart(
          title: const ChartTitle(text: 'Temperature Trend'),
          primaryXAxis: const CategoryAxis(),
          primaryYAxis: const NumericAxis(title: AxisTitle(text: '°C'), minimum: 20, maximum: 40),
          series: [
            LineSeries<ChartData, String>(
              dataSource: chartData,
              xValueMapper: (d, _) => d.time,
              yValueMapper: (d, _) => d.temperature,
              markerSettings: const MarkerSettings(isVisible: true),
              dataLabelSettings: const DataLabelSettings(isVisible: true),
            ),
          ],
        );
      case 1:
        return SfCartesianChart(
          title: const ChartTitle(text: 'Heart Rate Trend'),
          primaryXAxis: const CategoryAxis(),
          primaryYAxis: const NumericAxis(title: AxisTitle(text: 'BPM'), minimum: 60, maximum: 100),
          series: [
            LineSeries<ChartData, String>(
              dataSource: chartData,
              xValueMapper: (d, _) => d.time,
              yValueMapper: (d, _) => d.heartRate,
              color: Colors.red,
              markerSettings: const MarkerSettings(isVisible: true),
            ),
          ],
        );
      case 2:
        return SfCartesianChart(
          title: const ChartTitle(text: 'Fan Speed Trend'),
          primaryXAxis: const CategoryAxis(),
          primaryYAxis: const NumericAxis(title: AxisTitle(text: '%'), minimum: 0, maximum: 100),
          series: [
            ColumnSeries<ChartData, String>(
              dataSource: chartData,
              xValueMapper: (d, _) => d.time,
              yValueMapper: (d, _) => d.fanSpeed,
              dataLabelSettings: const DataLabelSettings(isVisible: true),
              color: Colors.cyan,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatsCards(dynamic data) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard('Current Temp', '${data.temperature.toStringAsFixed(1)}°C', Icons.thermostat, Colors.orange),
        _buildStatCard('Current HR', '${data.heartRate} BPM', Icons.favorite, Colors.red),
        _buildStatCard('Fan Speed', '${data.fanSpeed}%', Icons.speed, Colors.cyan),
        _buildStatCard('AI Confidence', '${(data.mlConfidence * 100).toStringAsFixed(0)}%', Icons.psychology, Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class ChartData {
  ChartData(this.time, this.temperature, this.heartRate, this.fanSpeed);
  final String time;
  final double temperature;
  final int heartRate;
  final int fanSpeed;
}