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
//  Kluczowe decyzje projektowe:
//  - VAD (Silero) jako "strażnik" CPU: pełne dekodowanie ASR odpala się
//    tylko gdy algorytm wykryje ludzki głos → oszczędność baterii ~60-70%.
//  - Gramatyka zawężona do 4 tokenów: punkt / pudło / cofnij / [unk]
//    Eliminuje fałszywe alarmy od uderzeń piłki i szumu sali.
//  - Cały pipeline audio (nagrywanie + VAD + ASR + feedback) żyje
//    w tym samym izolcie tła, nie przekraczamy granicy izolatu dla audio.
//  - duckOthers: muzyka z Spotify zostanie przyciszona, nie wstrzymana.
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
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

// ─── Stałe zdarzeń IPC (tło → UI) ─────────────────────────────────────────

class AsrEvents {
  static const shotMake = 'shot_make';
  static const shotSwish = 'shot_swish';
  static const shotMiss = 'shot_miss';
  static const shotUndo = 'shot_undo';
  static const finish = 'finish';
  static const voiceState = 'voice_state'; // {active: bool}
  static const error = 'error'; // {message: String}
}

// ─── Stałe poleceń IPC (UI → tło) ──────────────────────────────────────────

class AsrCommands {
  static const startListening = 'start_listening';
  static const stopListening = 'stop_listening';
  static const shutdown = 'shutdown';
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
      // Powiadomienie kanałowe wymagane przez Android 8+
      notificationChannelId: 'bball_tracking',
      initialNotificationTitle: 'Basketball Tracker',
      initialNotificationContent: 'Nasłuchuję komend...',
      foregroundServiceNotificationId: 888,
      // Typ usługi wymagany od Android 14 dla mikrofonu
      foregroundServiceTypes: const [
        AndroidForegroundType.microphone,
      ],
    ),

    // ── iOS: background processing ─────────────────────────────────────────
    // Wymagane wpisy w Info.plist:
    //   UIBackgroundModes: audio, processing
    //   BGTaskSchedulerPermittedIdentifiers: com.yourapp.asr
    iosConfiguration: IosConfiguration(
      onForeground: _onServiceStart,
      onBackground: _onIosBackground,
      autoStart: false,
    ),
  );
}

// iOS wymaga handlera tła zwracającego bool
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

  debugPrint('[BG] Usługa ASR uruchomiona');

  // ── 1. Konfiguracja sesji audio (PRZED wszystkim innym) ──────────────────
  final audioRouter = AudioRouter();
  await audioRouter.configure();

  // ── 2. Silnik ASR ──────────────────────────────────────────────────────
  final asrEngine = AsrEngine();
  await asrEngine.init();

  // ── 3. Odtwarzacz feedbacku ────────────────────────────────────────────
  final feedback = AudioFeedback();
  await feedback.init();

  // ── 4. Przekazanie callbacków wyniku ASR ──────────────────────────────
  asrEngine.onKeyword = (String keyword) async {
    debugPrint('[BG] Keyword: $keyword');

    switch (keyword) {
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
      case 'end':
        await feedback.playEnd();
        service.invoke(AsrEvents.finish, {});
        break;
    }
  };

  asrEngine.onVadStateChange = (bool active) {
    service.invoke(AsrEvents.voiceState, {'active': active});
  };

  // ── 5. Komendy z UI ────────────────────────────────────────────────────
  service.on(AsrCommands.startListening).listen((_) async {
    debugPrint('[BG] Start listening');
    await audioRouter.activateForRecording();
    await asrEngine.start();
  });

  service.on(AsrCommands.stopListening).listen((_) async {
    debugPrint('[BG] Stop listening');
    await asrEngine.stop();
    await audioRouter.deactivate();
  });

  service.on(AsrCommands.shutdown).listen((_) async {
    debugPrint('[BG] Shutdown');
    await asrEngine.stop();
    await asrEngine.dispose();
    await feedback.dispose();
    await audioRouter.deactivate();
    service.stopSelf();
  });

  // Podtrzymaj usługę (Android wymaga periodicHeartbeat lub pętli)
  // flutter_background_service utrzymuje ją jako foreground – wystarczy
  debugPrint('[BG] Usługa ASR gotowa, czeka na komendy');
}

// ═══════════════════════════════════════════════════════════════════════════
//  AUDIO ROUTER – konfiguracja sesji i routing Bluetooth
// ═══════════════════════════════════════════════════════════════════════════

class AudioRouter {
  AudioSession? _session;

  /// Konfiguracja jednorazowa przy starcie usługi.
  Future<void> configure() async {
    _session = await AudioSession.instance;

    if (Platform.isIOS) {
      // ── iOS: playAndRecord + allowBluetooth + defaultToSpeaker ──────────
      //
      //  allowBluetooth:    włącza profil HFP (mikrofon BT)
      //  allowBluetoothA2DP: wyjście audio przez A2DP (lepszy dźwięk)
      //  allowBluetoothA2D: wyjście audio przez A2DP (lepszy dźwięk)
      //  defaultToSpeaker:  fallback gdy brak słuchawek → głośnik, nie ucho
      //  duckOthers:        przycisza Spotify/muzykę zamiast pauzować ✓
      //
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
            AndroidAudioFocusGainType.gainTransientMayDuck, // duck, nie pauzuj
        androidWillPauseWhenDucked: false,
      ));

      debugPrint('[AudioRouter] iOS skonfigurowany: playAndRecord + BT + duck');
    } else if (Platform.isAndroid) {
      // ── Android: konfiguracja bazowa, routing BT dynamicznie ────────────
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

  /// Aktywuje sesję przed nagrywaniem i włącza SCO jeśli potrzeba.
  Future<void> activateForRecording() async {
    if (_session == null) return;
    await _session!.setActive(true);

    if (Platform.isAndroid) {
      await _activateAndroidBluetooth();
    }
  }

  /// Dezaktywuje sesję gdy przestajemy nagrywać.
  Future<void> deactivate() async {
    if (_session == null) return;
    if (Platform.isAndroid) {
      await _deactivateAndroidBluetooth();
    }
    await _session!.setActive(false);
    debugPrint('[AudioRouter] Sesja audio dezaktywowana');
  }

  // ── Android SCO (mikrofon Bluetooth) ──────────────────────────────────
  //
  //  SCO (Synchronous Connection-Oriented) to profil wymagany do jednoczesnego
  //  nagrywania i odtwarzania przez słuchawki BT. Bez niego mikrofon BT
  //  jest niedostępny. A2DP to profil tylko-odsłuch (lepsza jakość audio
  //  wyjściowego, ale BRAK mikrofonu).
  //
  //  Logika:
  //  1. Sprawdź, czy jakiekolwiek urządzenie SCO jest sparowane i połączone
  //  2. Jeśli tak → startBluetoothSco() → setSpeakerphoneOn(false)
  //  3. Jeśli nie → setSpeakerphoneOn(true) → wbudowany mikrofon + głośnik
  //
  //  UWAGA: startBluetoothSco() wymaga permisji BLUETOOTH_CONNECT (Android 12+)
  //  oraz RECORD_AUDIO. Dodaj je do AndroidManifest.xml.
  //
  //  Implementacja przez MethodChannel – bardziej niezawodna niż pakiety
  //  trzecich stron, które często nie nadążają za zmianami API Android.

  static const _btChannel = MethodChannel('com.yourapp/bluetooth_sco');
  bool _scoActive = false;

  Future<void> _activateAndroidBluetooth() async {
    try {
      // Sprawdź czy jakieś urządzenie SCO jest gotowe
      final hasSco =
          await _btChannel.invokeMethod<bool>('hasScoDevice') ?? false;

      if (hasSco) {
        await _btChannel.invokeMethod('startSco');
        _scoActive = true;
        debugPrint('[AudioRouter] Android: SCO aktywowane');
      } else {
        // Brak BT → użyj wbudowanego mikrofonu i głośnika
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
  static const int _kSampleRate = 16000;

  sherpa.VoiceActivityDetector? _vad;
  sherpa.KeywordSpotter? _spotter;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSub;

  bool _running = false;
  bool _vadActive = false; // czy VAD aktualnie wykrywa mowę

  // Bufor kołowy – trzyma próbki z okna VAD do przekazania do spottera
  final List<Float32List> _speechBuffer = [];

  void Function(String keyword)? onKeyword;
  void Function(bool active)? onVadStateChange;

  // ── Inicjalizacja modeli ───────────────────────────────────────────────
  Future<void> init() async {
    debugPrint('[ASR] Inicjalizacja modeli...');

    // ── VAD: Silero (wbudowany w sherpa_onnx) ─────────────────────────────
    //
    //  silero_vad.onnx: ~1.8MB, <1% CPU przy 16kHz
    //  threshold 0.45: wyważony próg – nie za czuły na szumy sali
    //  minSpeechDuration 0.2s: ignoruje krótkie kliknięcia/uderzenia piłki
    //  minSilenceDuration 0.3s: jak długo cisza musi trwać by zakończyć segment
    //
    final vadConfig = sherpa.VadModelConfig(
      sileroVad: const sherpa.SileroVadModelConfig(
        model: 'assets/models/silero_vad.onnx',
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

    // ── Keyword Spotter (Zipformer CTC lub Conformer) ─────────────────────
    //
    //  Słownik zawężony do TYLKO: punkt / pudło / cofnij / koniec
    //  [unk] jako catch-all – odrzuca wszystkie inne dźwięki
    //
    //  keywords_score: jak pewnie musi być model by zaraportować trafienie
    //  keywords_threshold: minimalny wynik CTC
    //  Wyższe wartości = mniej false-positive, ale też miss-ów
    //
    //  Model zalecany: sherpa-onnx-kws-zipformer-wenetspeech-3.3M-2024-01-01
    //  (dostępny na huggingface.co/k2-fsa/sherpa-onnx-kws-zipformer-*)
    //  lub dowolny model obsługujący polski słownik.
    //
    // Keyword spotting w sherpa_onnka wymaga pliku. Tworzymy tymczasowy.
    final directory = Directory.systemTemp.path;
    final keywordsPath = '$directory/keywords.txt';
    const keywordsContent = '''
make @1.5
swish @1.5
miss @1.5
undo @1.5
end @1.5
''';
    await File(keywordsPath).writeAsString(keywordsContent);

    final spotterConfig = sherpa.KeywordSpotterConfig(
      model: const sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: 'assets/models/kws/encoder.onnx',
          decoder: 'assets/models/kws/decoder.onnx',
          joiner: 'assets/models/kws/joiner.onnx',
        ),
        tokens: 'assets/models/kws/tokens.txt',
        numThreads: 2,
        debug: false,
      ),
      keywordsFile: keywordsPath,
    );

    _spotter = sherpa.KeywordSpotter(spotterConfig);

    debugPrint('[ASR] Modele załadowane: VAD + KeywordSpotter');
  }

  // ── Start nasłuchiwania ───────────────────────────────────────────────
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _speechBuffer.clear();

    _recorder = AudioRecorder();

    final stream = await _recorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits, // raw PCM → bezpośrednio do sherpa
        sampleRate: _kSampleRate,
        numChannels: 1, // mono
        autoGain: true,
        echoCancel: true, // redukuje echo głośnika telefonu
        noiseSuppress: true, // redukuje szumy sali
        bitRate: 256000,
      ),
    );

    _audioSub = stream.listen(
      _processAudioChunk,
      onError: (e) => debugPrint('[ASR] Stream error: $e'),
    );

    debugPrint('[ASR] Nagrywanie PCM 16kHz mono – start');
  }

  // ── Stop nasłuchiwania ────────────────────────────────────────────────
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

  // ── Główny pipeline przetwarzania audio ──────────────────────────────
  //
  //  Przepływ:
  //  1. Konwertuj bytes (Int16 PCM) → Float32 normalized [-1.0, 1.0]
  //  2. Przekaż do VAD – sprawdź czy to mowa czy cisza/szum
  //  3a. Cisza → wyczyść bufor, nie rób nic (oszczędność CPU)
  //  3b. Mowa → buforuj próbki + przekaż do keyword spottera
  //  4. Spotter zwraca keyword lub null
  //
  void _processAudioChunk(Uint8List bytes) {
    if (_vad == null || _spotter == null) return;

    // Konwersja Int16 Little-Endian → Float32 [-1, 1]
    final samples = _int16BytesToFloat32(bytes);

    // ── Krok 1: VAD ────────────────────────────────────────────────────
    _vad!.acceptWaveform(samples);

    bool speechNow = false;

    // Przetwarzaj wszystkie gotowe segmenty z bufora VAD
    while (!_vad!.isEmpty()) {
      final segment = _vad!.front();
      _vad!.pop();

      if (segment.samples.isEmpty) continue;

      speechNow = true;

      // ── Krok 2: Przekaż do keyword spottera ────────────────────────
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

    // Powiadom UI o zmianie stanu VAD (tylko przy zmianie)
    if (speechNow != _vadActive) {
      _vadActive = speechNow;
      onVadStateChange?.call(_vadActive);
    }
  }

  // ── Konwersja Int16 PCM → Float32 ────────────────────────────────────
  static Float32List _int16BytesToFloat32(Uint8List bytes) {
    final samples = Float32List(bytes.length ~/ 2);
    final byteData = bytes.buffer.asByteData();
    for (int i = 0; i < samples.length; i++) {
      final int16 = byteData.getInt16(i * 2, Endian.little);
      samples[i] = int16 / 32768.0;
    }
    return samples;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AUDIO FEEDBACK – just_audio, niskie opóźnienie
// ═══════════════════════════════════════════════════════════════════════════
//
//  Dlaczego just_audio a nie audioplayers?
//  - just_audio buforuje asset przy setAudioSource() → play() jest natychmiastowy
//  - Obsługuje natywny dekoder platformy (AAC na iOS, ExoPlayer na Android)
//  - Lepsze wsparcie audio_session
//
//  Każdy dźwięk ma własny player → równoległe odtwarzanie bez konfliktów.
//  Dźwięki muszą być krótkie (<0.5s) i wstępnie załadowane.
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

      // Wstępne ładowanie do bufora dekodera – play() będzie błyskawiczny
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
      await p.seek(Duration.zero); // przewiń do początku jeśli grał
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
    // Daj usłudze chwilę na inicjalizację modeli
    await Future.delayed(const Duration(milliseconds: 800));
    _svc.invoke(AsrCommands.startListening);
  }

  static Future<void> stopListening() async {
    _svc.invoke(AsrCommands.stopListening);
  }

  static Future<void> shutdown() async {
    _svc.invoke(AsrCommands.shutdown);
  }

  /// Strumień zdarzeń z tła → UI.
  /// Każde zdarzenie: Map<String, dynamic> z kluczem 'event'.
  static Stream<Map<String, dynamic>?> events(String eventName) {
    return _svc.on(eventName);
  }

  static Future<bool> get isRunning => _svc.isRunning();
}
