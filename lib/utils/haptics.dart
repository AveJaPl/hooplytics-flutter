import 'package:flutter/services.dart';

class Haptics {
  static bool enabled = true;

  static Future<void> lightImpact() async {
    if (enabled) await HapticFeedback.lightImpact();
  }

  static Future<void> mediumImpact() async {
    if (enabled) await HapticFeedback.mediumImpact();
  }

  static Future<void> heavyImpact() async {
    if (enabled) await HapticFeedback.heavyImpact();
  }

  static Future<void> selectionClick() async {
    if (enabled) await HapticFeedback.selectionClick();
  }

  static Future<void> vibrate() async {
    if (enabled) await HapticFeedback.vibrate();
  }
}
