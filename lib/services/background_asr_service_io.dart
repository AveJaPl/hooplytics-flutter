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

    // Wyczyść cache – wymuś ponowne skopiowanie modeli
    try {
      await ModelExtractor.clearCache();
      _status('Cache wyczyszczony');
    } catch (e) {
      _status('Cache error: $e');
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
      await File(keywordsPath).writeAsString(
        'MAKE @1.5\nSWISH @1.5\nMISS @1.5\nUNDO @1.5\nDONE @1.5\n',
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

    _feedback = _AudioFeedback();
    try {
      await _feedback!.init();
      _status('Dźwięki OK ✓');
    } catch (e) {
      _status('Dźwięki BŁĄD: $e (kontynuuję)');
    }

    _asrEngine!.onKeyword = (String keyword) async {
      _status('🎤 "$keyword"');
      switch (keyword) {
        case 'make':
          await _feedback?.playMake();
          onEvent(AsrEvents.shotMake, {});
          break;
        case 'swish':
          await _feedback?.playSwish();
          onEvent(AsrEvents.shotSwish, {});
          break;
        case 'miss':
          await _feedback?.playMiss();
          onEvent(AsrEvents.shotMiss, {});
          break;
        case 'undo':
          await _feedback?.playUndo();
          onEvent(AsrEvents.shotUndo, {});
          break;
        case 'done':
          await _feedback?.playEnd();
          onEvent(AsrEvents.finish, {});
          break;
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
    await _asrEngine?.stop();
    await _audioRouter?.deactivate();
    _running = false;
    _status('Zatrzymano');
  }

  Future<void> shutdown() async {
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
      await _session!.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.assistanceSonification,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ));
    }
  }

  Future<void> activateForRecording() async {
    if (_session == null) return;
    await _session!.setActive(true);
    if (Platform.isAndroid) await _activateAndroidBluetooth();
  }

  Future<void> deactivate() async {
    if (_session == null) return;
    if (Platform.isAndroid) await _deactivateAndroidBluetooth();
    await _session!.setActive(false);
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
    } on PlatformException catch (e) {
      debugPrint('[AudioRouter] BT error: $e');
    }
  }

  Future<void> _deactivateAndroidBluetooth() async {
    if (!_scoActive) return;
    try {
      await _btChannel.invokeMethod('stopSco');
      _scoActive = false;
    } on PlatformException catch (e) {
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
        maxSpeechDuration: 8.0,
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

    _recorder = AudioRecorder();
    final stream = await _recorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _kSampleRate,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
        bitRate: 256000,
      ),
    );

    _audioSub = stream.listen(
      _enqueueChunk,
      onError: (e) => debugPrint('[AsrEngine] Stream error: $e'),
    );
  }

  void _enqueueChunk(Uint8List bytes) {
    if (_processing) return;
    if (_vad == null || _spotter == null) return;

    _processing = true;
    Future(() {
      try {
        _processChunk(bytes);
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

    final samples = _int16ToFloat32(bytes);
    _vad!.acceptWaveform(samples);

    bool speechNow = false;
    while (!_vad!.isEmpty()) {
      final segment = _vad!.front();
      _vad!.pop();
      if (segment.samples.isEmpty) continue;
      speechNow = true;

      final stream = _spotter!.createStream();
      stream.acceptWaveform(samples: segment.samples, sampleRate: _kSampleRate);
      _spotter!.decode(stream);
      final result = _spotter!.getResult(stream);
      stream.free();

      final keyword = result.keyword.trim().toLowerCase();
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

  Future<void> init() async {
    _pMake = AudioPlayer();
    _pSwish = AudioPlayer();
    _pMiss = AudioPlayer();
    _pUndo = AudioPlayer();
    _pEnd = AudioPlayer();

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
    for (final p in [_pMake, _pSwish, _pMiss, _pUndo, _pEnd]) await p.dispose();
  }
}
