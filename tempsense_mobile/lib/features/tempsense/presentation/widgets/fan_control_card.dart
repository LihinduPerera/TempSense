import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/bloc/neck_cooler_bloc.dart';

class FanControlCard extends StatefulWidget {
  final int fanSpeed;
  final bool autoMode;
  final bool isConnected;

  const FanControlCard({
    super.key,
    required this.fanSpeed,
    required this.autoMode,
    required this.isConnected,
  });

  @override
  State<FanControlCard> createState() => _FanControlCardState();
}

class _FanControlCardState extends State<FanControlCard> {
  // OPTIMIZED: Local state for instant UI updates
  late int _localFanSpeed;
  late bool _localAutoMode;

  @override
  void initState() {
    super.initState();
    _localFanSpeed = widget.fanSpeed;
    _localAutoMode = widget.autoMode;
  }

  @override
  void didUpdateWidget(FanControlCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update from props if significantly different (avoid jitter)
    if ((widget.fanSpeed - _localFanSpeed).abs() > 2 || 
        widget.autoMode != _localAutoMode) {
      setState(() {
        _localFanSpeed = widget.fanSpeed;
        _localAutoMode = widget.autoMode;
      });
    }
  }

  void _setFanSpeed(int speed) {
    // OPTIMIZED: Update UI immediately
    setState(() {
      _localFanSpeed = speed;
      _localAutoMode = false;
    });
    
    // Then send to device
    context.read<NeckCoolerBloc>().add(SetFanSpeed(speed));
  }

  void _toggleAutoMode(bool value) {
    // OPTIMIZED: Update UI immediately
    setState(() {
      _localAutoMode = value;
    });
    
    // Then send to device
    context.read<NeckCoolerBloc>().add(SetAutoMode(value));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fan Control',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _localAutoMode ? 'Auto Mode' : 'Manual Mode',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _localAutoMode ? Colors.green : Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _localAutoMode,
                      onChanged: widget.isConnected ? _toggleAutoMode : null,
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: SfRadialGauge(
                axes: <RadialAxis>[
                  RadialAxis(
                    minimum: 0,
                    maximum: 100,
                    showLabels: false,
                    showTicks: false,
                    axisLineStyle: const AxisLineStyle(
                      thickness: 0.15,
                      cornerStyle: CornerStyle.bothCurve,
                      color: Colors.grey,
                      thicknessUnit: GaugeSizeUnit.factor,
                    ),
                    pointers: <GaugePointer>[
                      RangePointer(
                        value: _localFanSpeed.toDouble(),
                        cornerStyle: CornerStyle.bothCurve,
                        width: 0.15,
                        sizeUnit: GaugeSizeUnit.factor,
                        enableAnimation: true,
                        animationDuration: 300,
                        animationType: AnimationType.ease,
                        gradient: SweepGradient(
                          colors: [
                            Colors.blue.shade300,
                            Colors.blue,
                            Colors.blue.shade700,
                          ],
                        ),
                      ),
                      MarkerPointer(
                        value: _localFanSpeed.toDouble(),
                        markerType: MarkerType.circle,
                        color: Colors.blue,
                        borderWidth: 2,
                        borderColor: Colors.white,
                        enableAnimation: true,
                        animationDuration: 300,
                      ),
                    ],
                    annotations: <GaugeAnnotation>[
                      GaugeAnnotation(
                        positionFactor: 0.1,
                        widget: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_localFanSpeed%',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              'Current Speed',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _localFanSpeed.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '$_localFanSpeed%',
              activeColor: Colors.blue,
              inactiveColor: Colors.grey[300],
              onChanged: widget.isConnected && !_localAutoMode
                  ? (value) {
                      // OPTIMIZED: Update immediately as user drags
                      setState(() {
                        _localFanSpeed = value.toInt();
                      });
                    }
                  : null,
              onChangeEnd: widget.isConnected && !_localAutoMode
                  ? (value) {
                      // Send final value to device
                      context.read<NeckCoolerBloc>().add(SetFanSpeed(value.toInt()));
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSpeedButton(context, 0, 'OFF', Icons.power_off),
                _buildSpeedButton(context, 25, 'LOW', Icons.waves),
                _buildSpeedButton(context, 50, 'MED', Icons.waves_outlined),
                _buildSpeedButton(context, 75, 'HIGH', Icons.waves_sharp),
                _buildSpeedButton(context, 100, 'MAX', Icons.flash_on),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedButton(BuildContext context, int speed, String label, IconData icon) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: widget.isConnected && !_localAutoMode
              ? () => _setFanSpeed(speed)
              : null,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
            backgroundColor: _localFanSpeed == speed ? Colors.blue : Colors.grey[200],
            foregroundColor: _localFanSpeed == speed ? Colors.white : Colors.grey[600],
            disabledBackgroundColor: Colors.grey[100],
            disabledForegroundColor: Colors.grey[400],
          ),
          child: Icon(icon, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: widget.isConnected && !_localAutoMode ? Colors.grey[700] : Colors.grey[400],
          ),
        ),
      ],
    );
  }
}