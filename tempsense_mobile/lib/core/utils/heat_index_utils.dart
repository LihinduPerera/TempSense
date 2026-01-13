import 'dart:math' as math;

import 'package:flutter/material.dart';

double calculateHeatIndex(double temperatureC, double relativeHumidity) {
  // Below ~27°C heat index is not meaningful
  if (temperatureC <= 26.7) return temperatureC;

  final double t = temperatureC * 1.8 + 32.0; // °F
  final double r = relativeHumidity;

  double hi = -42.379 +
      2.04901523 * t +
      10.14333127 * r -
      0.22475541 * t * r -
      0.00683783 * t * t -
      0.05481717 * r * r +
      0.00122874 * t * t * r +
      0.00085282 * t * r * r -
      0.00000199 * t * t * r * r;

  // Adjustment for low humidity
  if (r < 13 && t > 80.0 && t < 112.0) {
    final double adj = ((13 - r) / 4) * math.sqrt((17 - (t - 95.0).abs()) / 17);
    hi -= adj;
  }
  // Adjustment for high humidity
  else if (r > 85 && t > 80.0 && t < 87.0) {
    final double adj = ((r - 85) / 10) * ((87 - t) / 5);
    hi += adj;
  }

  return (hi - 32.0) * 5 / 9; // back to °C
}

String getHeatIndexRiskLevel(double heatIndex) {
  if (heatIndex < 27) return 'Normal';
  if (heatIndex < 32) return 'Caution';
  if (heatIndex < 41) return 'Extreme Caution';
  if (heatIndex < 54) return 'Danger';
  return 'Extreme Danger';
}

Color getHeatIndexColor(double heatIndex) {
  if (heatIndex < 27) return Colors.green;
  if (heatIndex < 32) return Colors.yellow;
  if (heatIndex < 41) return Colors.orange;
  return Colors.red;
}