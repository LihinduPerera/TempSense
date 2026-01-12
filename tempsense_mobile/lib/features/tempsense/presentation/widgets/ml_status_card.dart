// FILE PATH: lib/features/tempsense/presentation/widgets/ml_status_card.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MLStatusCard extends StatelessWidget {
  final double mlConfidence;
  final bool autoMode;

  const MLStatusCard({
    super.key,
    required this.mlConfidence,
    required this.autoMode,
  });

  Color _getConfidenceColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (mlConfidence >= 0.8) return Colors.green[600]!;
    if (mlConfidence >= 0.5) return Colors.orange[600]!;
    return scheme.error;
  }

  String _getConfidenceText() {
    if (mlConfidence >= 0.8) return 'High Confidence';
    if (mlConfidence >= 0.5) return 'Moderate Confidence';
    return 'Low Confidence';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.brain,
                  color: autoMode ? Colors.green[600] : colorScheme.primary.withOpacity(0.6),
                  size: 28,
                ),
                const SizedBox(width: 16),
                Text(
                  'TinyML AI Engine',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Confidence Level', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7))),
                      const SizedBox(height: 8),
                      Text(
                        '${(mlConfidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _getConfidenceColor(context),
                        ),
                      ),
                      Text(_getConfidenceText(), style: TextStyle(color: _getConfidenceColor(context))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Control Mode', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: autoMode ? Colors.green.withOpacity(0.15) : colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          autoMode ? 'Active' : 'Monitoring',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: autoMode ? Colors.green[600] : colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            LinearProgressIndicator(
              value: mlConfidence,
              backgroundColor: colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(_getConfidenceColor(context)),
              minHeight: 10,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 16),
            Text(
              autoMode
                  ? 'AI is actively adjusting fan speed based on real-time sensor data.'
                  : 'AI is monitoring sensors but manual control is active.',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8), fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}