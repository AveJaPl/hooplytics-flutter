// lib/services/background_asr_service_web.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

class AsrEvents {
  static const shotMake = 'shot_make';
  static const shotSwish = 'shot_swish';
  static const shotMiss = 'shot_miss';
  static const shotUndo = 'shot_undo';
  static const finish = 'finish';
  static const voiceState = 'voice_state';
  static const status = 'status';
  static const error = 'error';
}

Future<void> initBackgroundService() async {}

class BackgroundAsrService {
  static final _controllers =
      <String, StreamController<Map<String, dynamic>?>>{};

  static Stream<Map<String, dynamic>?> events(String eventName) {
    _controllers[eventName] ??= StreamController.broadcast();
    return _controllers[eventName]!.stream;
  }

  static Future<void> startSession() async {
    debugPrint('[ASR] Web: voice not supported');
    _controllers[AsrEvents.error]
        ?.add({'message': 'Voice not supported on web'});
  }

  static Future<void> stopListening() async {}
  static Future<void> shutdown() async {}
  static Future<bool> get isRunning async => false;
}
