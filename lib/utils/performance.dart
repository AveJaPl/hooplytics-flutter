import 'package:flutter/material.dart';
import '../main.dart'; // To access AppColors

class PerformanceGuide {
  /// Standard thresholds for classification
  static const double thresholdHigh = 0.70;
  static const double thresholdMid = 0.50;

  /// Returns standard color for performance percentage (0.0 to 1.0)
  static Color colorFor(double pct) {
    if (pct >= thresholdHigh) return AppColors.green;
    if (pct >= thresholdMid) return AppColors.gold;
    return AppColors.red;
  }

  /// Returns standard letter grade for performance percentage
  static String gradeFor(double pct) {
    if (pct >= 0.85) return 'S';
    if (pct >= 0.75) return 'A';
    if (pct >= 0.65) return 'B';
    if (pct >= thresholdMid) return 'C';
    return 'D';
  }
}
