import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SensorCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String unit;
  final Color? valueColor;

  const SensorCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.unit,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.15), Colors.transparent],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: valueColor ?? color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Text(unit, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}