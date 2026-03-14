// lib/services/background_asr_service_io.dart

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'model_extractor.dart';

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

Future<void> initBackgroundService() async {
  debugPrint('[ASR] initBackgroundService: no-op');
}

// ═══════════════════════════════════════════════════════════════════════════
//  FASADA UI
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
//  IMPLEMENTACJA
// ═══════════════════════════════════════════════════════════════════════════

class _AsrServiceImpl {
  AudioRouter? _audioRouter;
  _AsrEngine? _asrEngine;
  _AudioFeedback? _feedback;
  bool _running = false;

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

    // Upewnij sie ze poprzednia sesja jest zamknięta
    await _asrEngine?.stop();
    await _asrEngine?.dispose();
    _asrEngine = null;

    _emit = onEvent;

    _status('Inicjalizacja...');

    try {
      await WakelockPlus.enable();
      _status('Wakelock OK');
    } catch (e) {
      _status('Wakelock error: $e');
    }

    _audioRouter = AudioRouter();
    try {
      await _audioRouter!.configure();
      _status('Audio session OK');
    } catch (e) {
      _status('Audio session BŁĄD: $e');
    }

    _status('Kopiuję modele...');
    Map<String, String> modelPaths;
    try {
      modelPaths = await ModelExtractor.extractAll();
      _status('Modele gotowe ✓');
    } catch (e) {
      _status('Modele BŁĄD: $e');
      onEvent(AsrEvents.error, {'message': 'Model extraction failed: $e'});
      return;
    }

    String keywordsPath;
    try {
      final dir = await getApplicationSupportDirectory();
      keywordsPath = '${dir.path}/kws_keywords.txt';
      // Keywords must use space-separated BPE tokens from tokens.txt.
      // ▁MAKE is a single token; others are spelled with per-character tokens.
      // ▁ prefix = word-start boundary (e.g. ▁S = word-initial S).
      await File(keywordsPath).writeAsString(
        '▁MAKE @1.5\n▁S W I S H @1.5\n▁MI S S @1.5\n▁UN D O @1.5\n▁DON E @1.5\n',
      );
      _status('Keywords OK');
    } catch (e) {
      _status('Keywords BŁĄD: $e');
      onEvent(AsrEvents.error, {'message': 'Keywords file failed: $e'});
      return;
    }

    _asrEngine = _AsrEngine(
      vadModelPath: modelPaths['silero_vad.onnx']!,
      encoderPath: modelPaths['kws_encoder.onnx']!,
      decoderPath: modelPaths['kws_decoder.onnx']!,
      joinerPath: modelPaths['kws_joiner.onnx']!,
      tokensPath: modelPaths['kws_tokens.txt']!,
      keywordsFilePath: keywordsPath,
    );

    try {
      await _asrEngine!.init();
      _status('ASR Engine OK ✓');
    } catch (e) {
      _status('ASR init BŁĄD: $e');
      onEvent(AsrEvents.error, {'message': 'ASR init failed: $e'});
      return;
    }

    // AudioFeedback (just_audio/ExoPlayer) is deferred until AFTER
    // the recorder is running. ExoPlayer steals AUDIOFOCUS from
    // AudioRecorder when initialized, muting the mic.
    // Sounds will be lazy-loaded on first keyword detection.

    _asrEngine!.onKeyword = (String keyword) async {
      _status('🎤 "$keyword"');

      // Emit the event FIRST (instant UI response).
      switch (keyword) {
        case 'make':
          onEvent(AsrEvents.shotMake, {});
          break;
        case 'swish':
          onEvent(AsrEvents.shotSwish, {});
          break;
        case 'miss':
          onEvent(AsrEvents.shotMiss, {});
          break;
        case 'undo':
          onEvent(AsrEvents.shotUndo, {});
          break;
        case 'done':
          onEvent(AsrEvents.finish, {});
          break;
      }

      // Play feedback sound. ExoPlayer will steal audio focus from
      // the recorder, so we pause recording, play, then restart.
      if (_feedback == null) {
        _feedback = _AudioFeedback();
        try {
          await _feedback!.init();
        } catch (e) {
          debugPrint('[ASR] Feedback init error: $e');
          _feedback = null;
        }
      }
      if (_feedback != null) {
        // Pause recorder to avoid AUDIOFOCUS_LOSS muting it.
        await _asrEngine?.stop();
        switch (keyword) {
          case 'make':
            await _feedback!.playMake();
            break;
          case 'swish':
            await _feedback!.playSwish();
            break;
          case 'miss':
            await _feedback!.playMiss();
            break;
          case 'undo':
            await _feedback!.playUndo();
            break;
          case 'done':
            await _feedback!.playEnd();
            break;
        }
        // Restart recorder after sound finishes (unless session ended).
        if (_running && keyword != 'done') {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await _asrEngine?.start();
        }
      }
    };

    _asrEngine!.onVadStateChange = (bool active) {
      onEvent(AsrEvents.voiceState, {'active': active});
    };

    _asrEngine!.onError = (String msg) {
      _status('❌ $msg');
    };

    try {
      await _audioRouter!.activateForRecording();
      await _asrEngine!.start();
      _running = true;
      _status('Nasłuchuję ✓');
    } catch (e) {
      _status('Start BŁĄD: $e');
      onEvent(AsrEvents.error, {'message': 'Start failed: $e'});
    }
  }

  Future<void> stopListening() async {
    debugPrint('[ASR] stopListening called from:');
    debugPrint(StackTrace.current.toString().split('\n').take(5).join('\n'));
    await _asrEngine?.stop();
    await _audioRouter?.deactivate();
    _running = false;
    _status('Zatrzymano');
  }

  Future<void> shutdown() async {
    debugPrint('[ASR] shutdown called from:');
    debugPrint(StackTrace.current.toString().split('\n').take(5).join('\n'));
    await _asrEngine?.stop();
    await _asrEngine?.dispose();
    await _feedback?.dispose();
    await _audioRouter?.deactivate();
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    _asrEngine = null;
    _feedback = null;
    _audioRouter = null;
    _running = false;
    _emit = null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AUDIO ROUTER
// ═══════════════════════════════════════════════════════════════════════════

class AudioRouter {
  AudioSession? _session;

  Future<void> configure() async {
    _session = await AudioSession.instance;
    if (Platform.isIOS) {
      await _session!.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          flags: AndroidAudioFlags.audibilityEnforced,
          usage: AndroidAudioUsage.assistanceSonification,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ));
    } else if (Platform.isAndroid) {
      // Intentionally skip audio session configuration on Android.
      // AudioRecord works without audio focus, and configuring
      // voiceCommunication/speech usage causes AUDIOFOCUS_LOSS when
      // ExoPlayer (just_audio) initializes, which mutes the mic.
    }
  }

  Future<void> activateForRecording() async {
    if (_session == null) return;
    // iOS requires explicit AVAudioSession activation.
    // Android AudioRecord does NOT need audio focus — skipping setActive()
    // prevents AUDIOFOCUS_LOSS conflicts with just_audio's ExoPlayer.
    if (Platform.isIOS) await _session!.setActive(true);
    if (Platform.isAndroid) await _activateAndroidBluetooth();
  }

  Future<void> deactivate() async {
    if (_session == null) return;
    if (Platform.isAndroid) await _deactivateAndroidBluetooth();
    if (Platform.isIOS) await _session!.setActive(false);
  }

  static const _btChannel = MethodChannel('com.yourapp/bluetooth_sco');
  bool _scoActive = false;

  Future<void> _activateAndroidBluetooth() async {
    try {
      final hasSco =
          await _btChannel.invokeMethod<bool>('hasScoDevice') ?? false;
      if (hasSco) {
        await _btChannel.invokeMethod('startSco');
        _scoActive = true;
      } else {
        await _btChannel.invokeMethod('setSpeakerphoneOn', true);
      }
    } catch (e) {
      // MissingPluginException or PlatformException — BT SCO not available,
      // continue without it (microphone still works via built-in speaker).
      debugPrint('[AudioRouter] BT SCO unavailable, skipping: $e');
    }
  }

  Future<void> _deactivateAndroidBluetooth() async {
    if (!_scoActive) return;
    try {
      await _btChannel.invokeMethod('stopSco');
      _scoActive = false;
    } catch (e) {
      debugPrint('[AudioRouter] stopSco error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ASR ENGINE
// ═══════════════════════════════════════════════════════════════════════════

class _AsrEngine {
  final String vadModelPath;
  final String encoderPath;
  final String decoderPath;
  final String joinerPath;
  final String tokensPath;
  final String keywordsFilePath;

  static const int _kSampleRate = 16000;
  static const int _kChunkSamples = 512;

  sherpa.VoiceActivityDetector? _vad;
  sherpa.KeywordSpotter? _spotter;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSub;

  bool _running = false;
  bool _vadActive = false;
  bool _processing = false;
  final List<Uint8List> _pendingChunks = [];
  int _chunkCount = 0;
  int _segmentCount = 0;

  void Function(String keyword)? onKeyword;
  void Function(bool active)? onVadStateChange;
  void Function(String msg)? onError;

  _AsrEngine({
    required this.vadModelPath,
    required this.encoderPath,
    required this.decoderPath,
    required this.joinerPath,
    required this.tokensPath,
    required this.keywordsFilePath,
  });

  Future<void> init() async {
    debugPrint('[AsrEngine] Init VAD: $vadModelPath');

    final vadConfig = sherpa.VadModelConfig(
      sileroVad: sherpa.SileroVadModelConfig(
        model: vadModelPath,
        threshold: 0.45,
        minSilenceDuration: 0.30,
        minSpeechDuration: 0.20,
        windowSize: _kChunkSamples,
        maxSpeechDuration: 30.0,
      ),
      sampleRate: _kSampleRate,
      numThreads: 1,
      debug: false,
    );

    _vad = sherpa.VoiceActivityDetector(
      config: vadConfig,
      bufferSizeInSeconds: 30,
    );
    debugPrint('[AsrEngine] VAD OK');

    final spotterConfig = sherpa.KeywordSpotterConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: encoderPath,
          decoder: decoderPath,
          joiner: joinerPath,
        ),
        tokens: tokensPath,
        numThreads: 2,
        debug: false,
      ),
      keywordsFile: keywordsFilePath,
    );

    debugPrint('[AsrEngine] Tworzę KeywordSpotter...');
    _spotter = sherpa.KeywordSpotter(spotterConfig);
    debugPrint('[AsrEngine] KeywordSpotter OK');
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _processing = false;
    _chunkCount = 0;
    _segmentCount = 0;
    _pendingChunks.clear();

    _recorder = AudioRecorder();
    final stream = await _recorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _kSampleRate,
        numChannels: 1,
        // autoGain/echoCancel/noiseSuppress require hardware audio processing
        // that is unavailable on many emulators and some devices — keep off.
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );

    _audioSub = stream.listen(
      _enqueueChunk,
      onError: (e) => debugPrint('[AsrEngine] Stream error: $e'),
      onDone: () => debugPrint('[AsrEngine] ⚠️ Audio stream DONE (closed by recorder)'),
    );
  }

  void _enqueueChunk(Uint8List bytes) {
    if (_vad == null || _spotter == null) return;

    _pendingChunks.add(bytes);

    if (_processing) return;
    _processing = true;

    Future(() {
      try {
        while (_pendingChunks.isNotEmpty && _running) {
          final chunk = _pendingChunks.removeAt(0);
          _processChunk(chunk);
        }
      } catch (e) {
        debugPrint('[AsrEngine] chunk error: $e');
        onError?.call(e.toString());
      } finally {
        _processing = false;
      }
    });
  }

  void _processChunk(Uint8List bytes) {
    if (_vad == null || _spotter == null) return;

    _chunkCount++;
    if (_chunkCount % 500 == 1) {
      debugPrint('[AsrEngine] chunk #$_chunkCount, bytes=${bytes.length}, segments=$_segmentCount, pending=${_pendingChunks.length}');
    }

    final samples = _int16ToFloat32(bytes);

    // Check if audio has any signal (not all zeros)
    if (_chunkCount % 500 == 1) {
      double maxAmp = 0;
      for (final s in samples) {
        if (s.abs() > maxAmp) maxAmp = s.abs();
      }
      debugPrint('[AsrEngine] audio maxAmp=${maxAmp.toStringAsFixed(4)}');
    }

    _vad!.acceptWaveform(samples);

    bool speechNow = false;
    while (!_vad!.isEmpty()) {
      final segment = _vad!.front();
      _vad!.pop();
      if (segment.samples.isEmpty) continue;
      _segmentCount++;
      speechNow = true;
      debugPrint('[AsrEngine] VAD segment #$_segmentCount, samples=${segment.samples.length}');

      final stream = _spotter!.createStream();
      stream.acceptWaveform(samples: segment.samples, sampleRate: _kSampleRate);
      _spotter!.decode(stream);
      final result = _spotter!.getResult(stream);
      stream.free();

      // Strip BPE word-boundary markers (▁) and inter-token spaces,
      // then trim and lowercase so switch cases like 'make' always match.
      final keyword = result.keyword
          .replaceAll('▁', '')
          .replaceAll(' ', '')
          .trim()
          .toLowerCase();
      debugPrint('[AsrEngine] spotter result: "${result.keyword}" -> "$keyword"');
      if (keyword.isNotEmpty && keyword != '[unk]') {
        debugPrint('[AsrEngine] ✓ "$keyword"');
        onKeyword?.call(keyword);
      }
    }

    if (speechNow != _vadActive) {
      _vadActive = speechNow;
      onVadStateChange?.call(_vadActive);
    }
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _processing = false;
    _pendingChunks.clear();
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder?.stop();
    _recorder?.dispose();
    _recorder = null;
    if (_vadActive) {
      _vadActive = false;
      onVadStateChange?.call(false);
    }
  }

  Future<void> dispose() async {
    await stop();
    _vad?.free();
    _spotter?.free();
    _vad = null;
    _spotter = null;
  }

  static Float32List _int16ToFloat32(Uint8List bytes) {
    final out = Float32List(bytes.length ~/ 2);
    final bd = bytes.buffer.asByteData();
    for (int i = 0; i < out.length; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AUDIO FEEDBACK
// ═══════════════════════════════════════════════════════════════════════════

class _AudioFeedback {
  late final AudioPlayer _pMake, _pSwish, _pMiss, _pUndo, _pEnd;
  bool _ready = false;

  AudioPlayer _createPlayer() =>
      AudioPlayer(handleInterruptions: false);

  Future<void> init() async {
    _pMake = _createPlayer();
    _pSwish = _createPlayer();
    _pMiss = _createPlayer();
    _pUndo = _createPlayer();
    _pEnd = _createPlayer();

    await Future.wait([
      _pMake.setAudioSource(AudioSource.asset('assets/sounds/hit.mp3')),
      _pSwish.setAudioSource(AudioSource.asset('assets/sounds/swish.mp3')),
      _pMiss.setAudioSource(AudioSource.asset('assets/sounds/miss.mp3')),
      _pUndo.setAudioSource(AudioSource.asset('assets/sounds/undo.mp3')),
      _pEnd.setAudioSource(AudioSource.asset('assets/sounds/end.mp3')),
    ]);
    _ready = true;
  }

  Future<void> _play(AudioPlayer p) async {
    if (!_ready) return;
    try {
      await p.seek(Duration.zero);
      await p.play();
    } catch (e) {
      debugPrint('Audio: $e');
    }
  }

  Future<void> playMake() => _play(_pMake);
  Future<void> playSwish() => _play(_pSwish);
  Future<void> playMiss() => _play(_pMiss);
  Future<void> playUndo() => _play(_pUndo);
  Future<void> playEnd() => _play(_pEnd);

  Future<void> dispose() async {
    for (final p in [_pMake, _pSwish, _pMiss, _pUndo, _pEnd]) {
      await p.dispose();
    }
  }
}
