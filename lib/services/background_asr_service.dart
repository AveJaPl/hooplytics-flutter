// lib/services/background_asr_service.dart
//
// ═══════════════════════════════════════════════════════════════════════════
//  ARCHITEKTURA USŁUGI W TLE
// ═══════════════════════════════════════════════════════════════════════════
//
//  ┌─────────────────────────────────────────────────────────────────────┐
//  │  Foreground Isolate (UI)                                            │
//  │  SessionTrackingScreen ──listen──▶ FlutterBackgroundService.invoke  │
//  └──────────────────────────────────────┬──────────────────────────────┘
//                                         │ IPC (JSON events)
//  ┌──────────────────────────────────────▼──────────────────────────────┐
//  │  Background Isolate (Foreground Service)                            │
//  │                                                                     │
//  │  ModelExtractor ──copy assets──▶ absolutne ścieżki na dysku        │
//  │       │                                                             │
//  │  AudioRouter ──configure──▶ audio_session (iOS/Android BT)         │
//  │       │                                                             │
//  │  AudioRecorder (record pkg) ──PCM 16 kHz──▶ RingBuffer             │
//  │                                                    │                │
//  │                                              SileroVAD              │
//  │                                             (sherpa_onnx)           │
//  │                                                    │ speech detected │
//  │                                            KeywordSpotter           │
//  │                                           (sherpa_onnx, offline)   │
//  │                                                    │ keyword hit     │
//  │                                            AudioFeedback            │
//  │                                             (just_audio)            │
//  │                                                    │                │
//  │                                          service.invoke(event)      │
//  └─────────────────────────────────────────────────────────────────────┘
//
//  KLUCZOWA ZMIANA vs poprzednia wersja:
//  - sherpa_onnx wymaga ABSOLUTNYCH ścieżek plików na dysku.
//    Ścieżki 'assets/models/...' NIE działają – assets są spakowane
//    w binarce aplikacji, nie istnieją jako pliki systemu plików.
//  - ModelExtractor (lib/services/model_extractor.dart) kopiuje modele
//    z asset bundle do getApplicationSupportDirectory() przy pierwszym
//    uruchomieniu, potem używa cache.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'model_extractor.dart';

// ─── Stałe zdarzeń IPC (tło → UI) ─────────────────────────────────────────

class AsrEvents {
  static const shotMake = 'shot_make';
  static const shotSwish = 'shot_swish';
  static const shotMiss = 'shot_miss';
  static const shotUndo = 'shot_undo';
  static const finish = 'finish';
  static const voiceState = 'voice_state'; // {active: bool}
  static const status = 'status'; // {msg: String} – debug panel w UI
  static const error = 'error'; // {message: String}
}

// ─── Stałe poleceń IPC (UI → tło) ──────────────────────────────────────────

class AsrCommands {
  static const startListening = 'start_listening';
  static const stopListening = 'stop_listening';
  static const shutdown = 'shutdown';
}

// ─── Helper statusu – wysyła do UI i drukuje w konsoli ─────────────────────

void _status(ServiceInstance svc, String msg) {
  debugPrint('[BG] $msg');
  svc.invoke(AsrEvents.status, {'msg': msg});
}

// ═══════════════════════════════════════════════════════════════════════════
//  INICJALIZACJA USŁUGI – wywołaj w main() przed runApp()
// ═══════════════════════════════════════════════════════════════════════════

Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    // ── Android: foreground service z trwałym powiadomieniem ──────────────
    androidConfiguration: AndroidConfiguration(
      onStart: _onServiceStart,
      isForegroundMode: true,
      autoStart: false,
      autoStartOnBoot: false,
      notificationChannelId: 'bball_tracking',
      initialNotificationTitle: 'Basketball Tracker',
      initialNotificationContent: 'Nasłuchuję komend...',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: const [
        AndroidForegroundType.microphone,
      ],
    ),

    // ── iOS: background processing ─────────────────────────────────────────
    iosConfiguration: IosConfiguration(
      onForeground: _onServiceStart,
      onBackground: _onIosBackground,
      autoStart: false,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════
//  PUNKT WEJŚCIA USŁUGI – uruchamia się w izolacje tła
// ═══════════════════════════════════════════════════════════════════════════

@pragma('vm:entry-point')
void _onServiceStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // ── 0. Inicjalizacja biblioteki natywnej (WYMAGANE) ──────────────────────
  sherpa.initBindings();

  _status(service, 'Usługa uruchomiona');

  // ── 1. Konfiguracja sesji audio (PRZED wszystkim innym) ──────────────────
  final audioRouter = AudioRouter();
  try {
    await audioRouter.configure();
    _status(service, 'Audio session OK');
  } catch (e) {
    _status(service, 'Audio session BŁĄD: $e');
  }

  // ── 2. Kopiuj modele z assets → absolutne ścieżki na dysku ──────────────
  //
  //  KLUCZOWE: sherpa_onnx nie potrafi czytać plików z Flutter asset bundle.
  //  ModelExtractor kopiuje je do getApplicationSupportDirectory() raz,
  //  przy kolejnych uruchomieniach używa cache (pliki już istnieją).
  //
  _status(service, 'Kopiuję modele...');
  Map<String, String> modelPaths;
  try {
    modelPaths = await ModelExtractor.extractAll();
    _status(service, 'Modele gotowe ✓');
  } catch (e) {
    _status(service, 'Modele BŁĄD: $e');
    service.invoke(AsrEvents.error, {'message': 'Model extraction failed: $e'});
    return;
  }

  // ── 3. Plik keywords – też musi być absolutną ścieżką ───────────────────
  //
  //  Directory.systemTemp jest niedostępny na iOS w izolacje tła.
  //  Używamy getApplicationSupportDirectory() – zawsze dostępne.
  //
  String keywordsPath;
  try {
    final dir = await getApplicationSupportDirectory();
    keywordsPath = '${dir.path}/kws_keywords.txt';
    await File(keywordsPath).writeAsString(
      'make @1.5\nswish @1.5\nmiss @1.5\nundo @1.5\ndone @1.5\n',
    );
    _status(service, 'Keywords OK');
  } catch (e) {
    _status(service, 'Keywords BŁĄD: $e');
    service.invoke(AsrEvents.error, {'message': 'Keywords file failed: $e'});
    return;
  }

  // ── 4. Silnik ASR ──────────────────────────────────────────────────────
  final asrEngine = AsrEngine(
    vadModelPath: modelPaths['silero_vad.onnx']!,
    encoderPath: modelPaths['kws_encoder.onnx']!,
    decoderPath: modelPaths['kws_decoder.onnx']!,
    joinerPath: modelPaths['kws_joiner.onnx']!,
    tokensPath: modelPaths['kws_tokens.txt']!,
    keywordsFilePath: keywordsPath,
  );

  try {
    await asrEngine.init();
    _status(service, 'ASR Engine OK ✓');
  } catch (e) {
    _status(service, 'ASR init BŁĄD: $e');
    service.invoke(AsrEvents.error, {'message': 'ASR init failed: $e'});
    return;
  }

  // ── 5. Odtwarzacz feedbacku ────────────────────────────────────────────
  final feedback = AudioFeedback();
  try {
    await feedback.init();
    _status(service, 'Dźwięki OK ✓');
  } catch (e) {
    // Nie przerywamy – aplikacja działa bez dźwięku
    _status(service, 'Dźwięki BŁĄD: $e (kontynuuję)');
  }

  // ── 6. Przekazanie callbacków wyniku ASR ──────────────────────────────
  asrEngine.onKeyword = (String keyword) async {
    final k = keyword.trim().toLowerCase();
    _status(service, '🎤 "$k"');
    switch (k) {
      case 'make':
        await feedback.playMake();
        service.invoke(AsrEvents.shotMake, {});
        break;
      case 'swish':
        await feedback.playSwish();
        service.invoke(AsrEvents.shotSwish, {});
        break;
      case 'miss':
        await feedback.playMiss();
        service.invoke(AsrEvents.shotMiss, {});
        break;
      case 'undo':
        await feedback.playUndo();
        service.invoke(AsrEvents.shotUndo, {});
        break;
      case 'done':
        await feedback.playEnd();
        service.invoke(AsrEvents.finish, {});
        break;
    }
  };

  asrEngine.onVadStateChange = (bool active) {
    service.invoke(AsrEvents.voiceState, {'active': active});
  };

  // ── 7. Komendy z UI ────────────────────────────────────────────────────
  service.on(AsrCommands.startListening).listen((_) async {
    _status(service, 'Start nasłuchiwania...');
    try {
      await audioRouter.activateForRecording();
      await asrEngine.start();
      _status(service, 'Nasłuchuję ✓');
    } catch (e) {
      _status(service, 'Start BŁĄD: $e');
      service.invoke(AsrEvents.error, {'message': 'Start failed: $e'});
    }
  });

  service.on(AsrCommands.stopListening).listen((_) async {
    debugPrint('[BG] Stop listening');
    await asrEngine.stop();
    await audioRouter.deactivate();
    _status(service, 'Zatrzymano');
  });

  service.on(AsrCommands.shutdown).listen((_) async {
    debugPrint('[BG] Shutdown');
    await asrEngine.stop();
    await asrEngine.dispose();
    await feedback.dispose();
    await audioRouter.deactivate();
    service.stopSelf();
  });

  _status(service, 'Gotowy – czekam na start_listening');
}

// ═══════════════════════════════════════════════════════════════════════════
//  AUDIO ROUTER – konfiguracja sesji i routing Bluetooth
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
      debugPrint('[AudioRouter] iOS skonfigurowany: playAndRecord + BT + duck');
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
      debugPrint('[AudioRouter] Android skonfigurowany: base + duck');
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
    debugPrint('[AudioRouter] Sesja audio dezaktywowana');
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
        debugPrint('[AudioRouter] Android: SCO aktywowane');
      } else {
        await _btChannel.invokeMethod('setSpeakerphoneOn', true);
        debugPrint('[AudioRouter] Android: głośnik wbudowany (brak BT)');
      }
    } on PlatformException catch (e) {
      debugPrint('[AudioRouter] BT error: $e – fallback do wbudowanego');
    }
  }

  Future<void> _deactivateAndroidBluetooth() async {
    if (!_scoActive) return;
    try {
      await _btChannel.invokeMethod('stopSco');
      _scoActive = false;
      debugPrint('[AudioRouter] Android: SCO zatrzymane');
    } on PlatformException catch (e) {
      debugPrint('[AudioRouter] stopSco error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ASR ENGINE – VAD → KeywordSpotter pipeline
// ═══════════════════════════════════════════════════════════════════════════

class AsrEngine {
  // Absolutne ścieżki plików – przekazane z ModelExtractor
  final String vadModelPath;
  final String encoderPath;
  final String decoderPath;
  final String joinerPath;
  final String tokensPath;
  final String keywordsFilePath;

  static const int _kSampleRate = 16000;

  sherpa.VoiceActivityDetector? _vad;
  sherpa.KeywordSpotter? _spotter;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSub;

  bool _running = false;
  bool _vadActive = false;

  final List<Float32List> _speechBuffer = [];

  void Function(String keyword)? onKeyword;
  void Function(bool active)? onVadStateChange;

  AsrEngine({
    required this.vadModelPath,
    required this.encoderPath,
    required this.decoderPath,
    required this.joinerPath,
    required this.tokensPath,
    required this.keywordsFilePath,
  });

  Future<void> init() async {
    debugPrint('[ASR] Inicjalizacja modeli...');
    debugPrint('[ASR] VAD: $vadModelPath');
    debugPrint('[ASR] Encoder: $encoderPath');
    debugPrint('[ASR] Keywords: $keywordsFilePath');

    // ── VAD: Silero ────────────────────────────────────────────────────────
    final vadConfig = sherpa.VadModelConfig(
      sileroVad: sherpa.SileroVadModelConfig(
        model: vadModelPath, // ABSOLUTNA ścieżka na dysku
        threshold: 0.45,
        minSilenceDuration: 0.30,
        minSpeechDuration: 0.20,
        windowSize: 512,
        maxSpeechDuration: 8.0,
      ),
      numThreads: 1,
      debug: false,
      sampleRate: _kSampleRate,
    );

    _vad = sherpa.VoiceActivityDetector(
      config: vadConfig,
      bufferSizeInSeconds: 30,
    );

    // ── Keyword Spotter ────────────────────────────────────────────────────
    final spotterConfig = sherpa.KeywordSpotterConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: encoderPath, // ABSOLUTNA ścieżka na dysku
          decoder: decoderPath,
          joiner: joinerPath,
        ),
        tokens: tokensPath, // ABSOLUTNA ścieżka na dysku
        numThreads: 2,
        debug: false,
      ),
      keywordsFile: keywordsFilePath, // ABSOLUTNA ścieżka na dysku
    );

    _spotter = sherpa.KeywordSpotter(spotterConfig);
    debugPrint('[ASR] Modele załadowane: VAD + KeywordSpotter');
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _speechBuffer.clear();

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
      _processAudioChunk,
      onError: (e) => debugPrint('[ASR] Stream error: $e'),
    );

    debugPrint('[ASR] Nagrywanie PCM 16kHz mono – start');
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder?.stop();
    _recorder?.dispose();
    _recorder = null;
    _speechBuffer.clear();
    if (_vadActive) {
      _vadActive = false;
      onVadStateChange?.call(false);
    }
    debugPrint('[ASR] Zatrzymano nagrywanie');
  }

  Future<void> dispose() async {
    await stop();
    _vad?.free();
    _spotter?.free();
    _vad = null;
    _spotter = null;
  }

  void _processAudioChunk(Uint8List bytes) {
    if (_vad == null || _spotter == null) return;

    final samples = _int16BytesToFloat32(bytes);
    _vad!.acceptWaveform(samples);

    bool speechNow = false;

    while (!_vad!.isEmpty()) {
      final segment = _vad!.front();
      _vad!.pop();
      if (segment.samples.isEmpty) continue;
      speechNow = true;

      final stream = _spotter!.createStream();
      stream.acceptWaveform(
        samples: segment.samples,
        sampleRate: _kSampleRate,
      );
      _spotter!.decode(stream);
      final result = _spotter!.getResult(stream);
      stream.free();

      final keyword = result.keyword.trim().toLowerCase();
      if (keyword.isNotEmpty && keyword != '[unk]') {
        debugPrint('[ASR] ✓ Keyword wykryty: "$keyword"');
        onKeyword?.call(keyword);
      }
    }

    if (speechNow != _vadActive) {
      _vadActive = speechNow;
      onVadStateChange?.call(_vadActive);
    }
  }

  static Float32List _int16BytesToFloat32(Uint8List bytes) {
    final samples = Float32List(bytes.length ~/ 2);
    final byteData = bytes.buffer.asByteData();
    for (int i = 0; i < samples.length; i++) {
      samples[i] = byteData.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AUDIO FEEDBACK – just_audio, niskie opóźnienie
// ═══════════════════════════════════════════════════════════════════════════

class AudioFeedback {
  late final AudioPlayer _pMake;
  late final AudioPlayer _pSwish;
  late final AudioPlayer _pMiss;
  late final AudioPlayer _pUndo;
  late final AudioPlayer _pEnd;

  bool _ready = false;

  Future<void> init() async {
    try {
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
      debugPrint('[AudioFeedback] Dźwięki wstępnie załadowane');
    } catch (e) {
      debugPrint('[AudioFeedback] Init error: $e');
      _ready = false;
    }
  }

  Future<void> _play(AudioPlayer p) async {
    if (!_ready) return;
    try {
      await p.seek(Duration.zero);
      await p.play();
    } catch (e) {
      debugPrint('[AudioFeedback] Play error: $e');
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

// ═══════════════════════════════════════════════════════════════════════════
//  POMOCNIK UI – statyczna fasada dla session_tracking_screen.dart
// ═══════════════════════════════════════════════════════════════════════════

class BackgroundAsrService {
  static final _svc = FlutterBackgroundService();

  static Future<void> startSession() async {
    await _svc.startService();
    // Czas na inicjalizację modeli (~1-2s przy pierwszym uruchomieniu)
    await Future.delayed(const Duration(milliseconds: 800));
    _svc.invoke(AsrCommands.startListening);
  }

  static Future<void> stopListening() async {
    _svc.invoke(AsrCommands.stopListening);
  }

  static Future<void> shutdown() async {
    _svc.invoke(AsrCommands.shutdown);
  }

  static Stream<Map<String, dynamic>?> events(String eventName) {
    return _svc.on(eventName);
  }

  static Future<bool> get isRunning => _svc.isRunning();
}
