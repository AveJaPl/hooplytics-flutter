import 'dart:io';
import 'package:flutter/services.dart';

class Haptics {
  static bool enabled = true;

  static bool get _isAndroid => Platform.isAndroid;

  static Future<void> lightImpact() async {
    if (!enabled) return;
    if (_isAndroid) {
      await HapticFeedback.vibrate();
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  static Future<void> mediumImpact() async {
    if (!enabled) return;
    if (_isAndroid) {
      await HapticFeedback.vibrate();
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> heavyImpact() async {
    if (!enabled) return;
    if (_isAndroid) {
      await HapticFeedback.vibrate();
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  static Future<void> selectionClick() async {
    if (enabled) await HapticFeedback.selectionClick();
  }

  static Future<void> vibrate() async {
    if (enabled) await HapticFeedback.vibrate();
  }
}
