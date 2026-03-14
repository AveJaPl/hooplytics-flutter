// lib/services/background_asr_service_io.dart

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

// ═══════════════════════════════════════════════════════════════════════════
//  PUBLIC FACADE (unchanged API)
// ═══════════════════════════════════════════════════════════════════════════

class BackgroundAsrService {
  static final _instance = _AsrServiceImpl();
  static final _controllers =
      <String, StreamController<Map<String, dynamic>?>>{};

  static Stream<Map<String, dynamic>?> events(String eventName) {
    _controllers[eventName] ??= StreamController.broadcast();
    return _controllers[eventName]!.stream;
  }

  static void _emit(String eventName, [Map<String, dynamic>? data]) {
    _controllers[eventName]?.add(data ?? {});
  }

  static Future<void> startSession() async {
    await _instance.startSession(onEvent: _emit);
  }

  static Future<void> stopListening() async {
    await _instance.stopListening();
  }

  static Future<void> shutdown() async {
    await _instance.shutdown();
  }

  static Future<bool> get isRunning async => _instance.isRunning;
}

// ═══════════════════════════════════════════════════════════════════════════
//  IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════

class _AsrServiceImpl {
  final SpeechToText _stt = SpeechToText();
  _AudioFeedback? _feedback;
  bool _running = false;
  bool _listening = false;
  Timer? _restartTimer;

  bool get isRunning => _running;

  void Function(String, Map<String, dynamic>?)? _emit;

  void _status(String msg) {
    debugPrint('[ASR] $msg');
    _emit?.call(AsrEvents.status, {'msg': msg});
  }

  Future<void> startSession({
    required void Function(String, Map<String, dynamic>?) onEvent,
  }) async {
    if (_running) return;
    _emit = onEvent;

    _status('Inicjalizacja...');

    try {
      await WakelockPlus.enable();
    } catch (e) {
      _status('Wakelock error: $e');
    }

    final available = await _stt.initialize(
      onStatus: _onSttStatus,
      onError: _onSttError,
      debugLogging: true,
    );

    if (!available) {
      _status('Speech recognition niedostępne');
      onEvent(AsrEvents.error, {'message': 'Speech recognition unavailable'});
      return;
    }

    _status('STT zainicjalizowane');

    // Init audio feedback (audioplayers / SoundPool — no audio focus conflict)
    _feedback = _AudioFeedback();
    try {
      await _feedback!.init();
      _status('Audio feedback OK');
    } catch (e) {
      debugPrint('[ASR] Feedback init error: $e');
      _feedback = null;
    }

    _running = true;
    await _startListening();
  }

  Future<void> _startListening() async {
    if (!_running || _listening) return;

    try {
      _listening = true;
      _emit?.call(AsrEvents.voiceState, {'active': true});

      // ignore: deprecated_member_use
      await _stt.listen(
        onResult: _onSttResult,
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );

      _status('Nasłuchuję...');
    } catch (e) {
      _listening = false;
      _status('Listen error: $e');
      _scheduleRestart();
    }
  }

  void _onSttResult(SpeechRecognitionResult result) {
    if (!_running) return;

    final text = result.recognizedWords.toLowerCase().trim();
    if (text.isEmpty) return;

    debugPrint('[ASR] result: "$text" final=${result.finalResult}');

    // Only process final results to avoid duplicate triggers
    if (!result.finalResult) return;

    _matchKeywords(text);
  }

  void _matchKeywords(String text) {
    // Split into words and check each one.
    // Process only the LAST keyword found to avoid duplicates
    // from partial → final result overlap.
    final words = text.split(RegExp(r'\s+'));

    String? lastKeyword;
    for (final word in words) {
      final matched = _matchWord(word);
      if (matched != null) lastKeyword = matched;
    }

    if (lastKeyword != null) {
      _handleKeyword(lastKeyword);
    }
  }

  String? _matchWord(String word) {
    // Support English and Polish keywords
    switch (word) {
      case 'make':
      case 'made':
      case 'mak':
      case 'trafiony':
      case 'trafienie':
        return 'make';
      case 'swish':
      case 'świszcz':
        return 'swish';
      case 'miss':
      case 'missed':
      case 'mis':
      case 'pudło':
      case 'pudlo':
        return 'miss';
      case 'undo':
      case 'cofnij':
        return 'undo';
      case 'done':
      case 'finish':
      case 'stop':
      case 'koniec':
        return 'done';
      default:
        return null;
    }
  }

  Future<void> _handleKeyword(String keyword) async {
    _status('Keyword: "$keyword"');

    switch (keyword) {
      case 'make':
        _emit?.call(AsrEvents.shotMake, {});
        break;
      case 'swish':
        _emit?.call(AsrEvents.shotSwish, {});
        break;
      case 'miss':
        _emit?.call(AsrEvents.shotMiss, {});
        break;
      case 'undo':
        _emit?.call(AsrEvents.shotUndo, {});
        break;
      case 'done':
        _emit?.call(AsrEvents.finish, {});
        break;
    }

    // Play feedback sound
    await _feedback?.play(keyword);
  }

  void _onSttStatus(String status) {
    debugPrint('[ASR] STT status: $status');

    if (status == 'notListening' || status == 'done') {
      _listening = false;
      _emit?.call(AsrEvents.voiceState, {'active': false});

      // Auto-restart listening after a short delay
      if (_running) {
        _scheduleRestart();
      }
    }
  }

  void _onSttError(SpeechRecognitionError error) {
    debugPrint('[ASR] STT error: ${error.errorMsg} permanent=${error.permanent}');
    _listening = false;

    if (error.permanent) {
      _status('Błąd STT: ${error.errorMsg}');
      _emit?.call(AsrEvents.error, {'message': error.errorMsg});
    }

    // Restart even after non-permanent errors
    if (_running) {
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 300), () {
      if (_running && !_listening) {
        _startListening();
      }
    });
  }

  Future<void> stopListening() async {
    _restartTimer?.cancel();
    _running = false;
    _listening = false;
    await _stt.stop();
    _emit?.call(AsrEvents.voiceState, {'active': false});
    _status('Zatrzymano');
  }

  Future<void> shutdown() async {
    _restartTimer?.cancel();
    _running = false;
    _listening = false;
    await _stt.stop();
    await _stt.cancel();
    await _feedback?.dispose();
    _feedback = null;
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    _emit = null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AUDIO FEEDBACK (audioplayers — uses SoundPool on Android, no focus theft)
// ═══════════════════════════════════════════════════════════════════════════

class _AudioFeedback {
  final _players = <String, AudioPlayer>{};

  static const _soundMap = {
    'make': 'assets/sounds/hit.mp3',
    'swish': 'assets/sounds/swish.mp3',
    'miss': 'assets/sounds/miss.mp3',
    'undo': 'assets/sounds/undo.mp3',
    'done': 'assets/sounds/end.mp3',
  };

  Future<void> init() async {
    for (final entry in _soundMap.entries) {
      final player = AudioPlayer();
      // Set low-latency mode for immediate feedback
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setSource(AssetSource(entry.value.replaceFirst('assets/', '')));
      _players[entry.key] = player;
    }
  }

  Future<void> play(String keyword) async {
    final player = _players[keyword];
    if (player == null) return;
    try {
      await player.stop();
      await player.resume();
    } catch (e) {
      debugPrint('[AudioFeedback] play error: $e');
    }
  }

  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}
