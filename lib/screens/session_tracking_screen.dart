import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'session_setup_screen.dart';
import '../models/session.dart';
import '../models/shot.dart';
import '../services/session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:audioplayers/audioplayers.dart';

enum ShotResult { miss, make, swish }

// ─────────────────────────────────────────────────────────────────────────────
//  VOICE ENGINE
//
//  Kluczowa zmiana architektury vs poprzednie wersje:
//
//  POPRZEDNIO: czekaj na ciszę (pauseFor) → dostań finalResult → wykonaj
//  TERAZ:      partial results → matchuj słowo kluczowe natychmiast → wykonaj
//
//  Dzięki temu latencja = czas rozpoznania słowa (~300-500ms), nie czas ciszy.
//  Użytkownik może mówić komendy jedna po drugiej bez czekania.
//
//  Cykl życia:
//  1. _listen() startuje sesję STT
//  2. onStatus 'listening' → _utteranceHandled = false (gotowy na komendę)
//  3. onResult (partial) → znajdź komendę → wykonaj → _utteranceHandled = true
//  4. onStatus 'done' → _scheduleRestart(120ms)
//  5. Wróć do 1
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceEngine {
  final SpeechToText _stt = SpeechToText();
  bool available = false;

  bool _wantOn = false;
  bool _isStarting = false;
  bool _utteranceHandled = false;

  // Dedup: zapobiega podwójnemu wyzwoleniu gdy iOS oddaje partial 2x z tą samą treścią
  String _lastHandledText = '';
  DateTime _lastHandledAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _dedupMs = 400;

  Timer? _restartTimer;

  void Function(String command)? onCommand;
  void Function(bool listening)? onStateChange;

  Future<bool> init() async {
    try {
      available = await _stt.initialize(
        onStatus: _onStatus,
        onError: (err) {
          debugPrint('STT error: ${err.errorMsg} permanent=${err.permanent}');
          onStateChange?.call(false);
          if (!err.permanent) _scheduleRestart(ms: 1000);
        },
      );
      debugPrint('STT available=$available');
    } catch (e) {
      debugPrint('STT init threw: $e');
      available = false;
    }
    return available;
  }

  void start() {
    if (!available) return;
    _wantOn = true;
    _utteranceHandled = false;
    _lastHandledText = '';
    _listen();
  }

  void stop() {
    _wantOn = false;
    _restartTimer?.cancel();
    _stt.cancel();
    _isStarting = false;
    onStateChange?.call(false);
  }

  void dispose() => stop();

  Future<void> _listen() async {
    if (!_wantOn || !available) return;
    if (_isStarting) return; // reentrant guard

    _isStarting = true;
    try {
      if (_stt.isListening) {
        _stt.cancel();
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (!_wantOn) return;

      await _stt.listen(
        onResult: _onResult,
        listenFor: const Duration(seconds: 50),
        // pauseFor: używamy 1500ms jako siatki bezpieczeństwa.
        // Przy partialResults nie ma znaczenia dla latencji – reagujemy wcześniej.
        // Nie może być za krótkie bo iOS będzie restartował co chwilę.
        pauseFor: const Duration(milliseconds: 1500),
        listenOptions: SpeechListenOptions(
          partialResults: true, // ← KLUCZOWE: reaguj natychmiast
          listenMode: ListenMode.dictation,
          cancelOnError: false,
        ),
        localeId: 'pl_PL',
      );
    } catch (e) {
      debugPrint('STT listen threw: $e');
      _scheduleRestart(ms: 1200);
    } finally {
      _isStarting = false;
    }
  }

  void _onStatus(String status) {
    debugPrint('STT status: $status');
    switch (status) {
      case 'listening':
        _utteranceHandled = false; // nowa wypowiedź – odblokuj komendę
        onStateChange?.call(true);
        break;
      case 'done':
        onStateChange?.call(false);
        _scheduleRestart(ms: 120); // minimal gap, prawie ciągłe nasłuchiwanie
        break;
      // 'notListening' ignorujemy – pojawia się przed 'listening' przy starcie
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    final raw = result.recognizedWords.toLowerCase().trim();
    if (raw.isEmpty) return;
    debugPrint('STT result final=${result.finalResult}: "$raw"');

    // Już obsłużyliśmy tę wypowiedź
    if (_utteranceHandled) return;

    // Dedup: ten sam tekst w oknie 400ms
    final now = DateTime.now();
    if (raw == _lastHandledText &&
        now.difference(_lastHandledAt).inMilliseconds < _dedupMs) {
      return;
    }

    final cmd = _parse(raw);
    if (cmd == null) return;

    _utteranceHandled = true;
    _lastHandledText = raw;
    _lastHandledAt = now;
    debugPrint('STT → "$cmd" from "$raw"');
    onCommand?.call(cmd);
  }

  String? _parse(String raw) {
    // Sprawdzaj od najbardziej specyficznych (swish przed make)
    if (raw.contains('czysto') ||
        raw.contains('czysta') ||
        raw.contains('swish') ||
        raw.contains('swoosh')) {
      return 'swish';
    }

    if (raw.contains('punkt') ||
        raw.contains('traf') ||
        raw.contains('make') ||
        raw.contains('yes') ||
        raw.contains('wpadł') ||
        raw.contains('wpadla') ||
        raw.contains('wpadlo')) {
      return 'make';
    }

    if (raw.contains('pudło') ||
        raw.contains('pudlo') ||
        raw.contains('miss') ||
        raw.contains('chybił') ||
        raw.contains('chybil') ||
        _word(raw, 'pud')) {
      return 'miss';
    }

    if (raw.contains('cofnij') ||
        raw.contains('wróć') ||
        raw.contains('wroc') ||
        raw.contains('undo') ||
        raw.contains('back') ||
        raw.contains('anuluj')) {
      return 'undo';
    }

    if (raw.contains('koniec') ||
        raw.contains('zakończ') ||
        raw.contains('zakoncz') ||
        raw.contains('stop') ||
        raw.contains('finish') ||
        raw.contains('end') ||
        raw.contains('skończ') ||
        raw.contains('skoncz')) {
      return 'finish';
    }

    return null;
  }

  // Sprawdź czy `word` jest osobnym słowem w tekście (nie podciągiem)
  bool _word(String text, String word) =>
      RegExp(r'\b' + RegExp.escape(word) + r'\b').hasMatch(text);

  void _scheduleRestart({required int ms}) {
    if (!_wantOn) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: ms), () {
      if (_wantOn && !_isStarting) _listen();
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AUDIO MANAGER
//
//  AVAudioSessionCategory.ambient + mixWithOthers = dźwięki PRZEZ mikrofon,
//  bez przerywania sesji STT. To była główna przyczyna crashy.
// ─────────────────────────────────────────────────────────────────────────────

class _AudioManager {
  AudioPlayer? _player;
  bool _ready = false;

  Future<void> init() async {
    try {
      _player = AudioPlayer();
      await _player!.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));
      // Pre-load żeby pierwsze odtworzenie było bez opóźnienia
      await AudioCache.instance.load('sounds/hit.mp3');
      await AudioCache.instance.load('sounds/miss.mp3');
      _ready = true;
      debugPrint('Audio ready');
    } catch (e) {
      debugPrint('Audio init error: $e');
      // Nie crashuj – haptic zawsze działa jako fallback
      _ready = false;
    }
  }

  void playHit() {
    HapticFeedback.mediumImpact();
    if (!_ready) return;
    try {
      _player?.play(AssetSource('sounds/hit.mp3'), volume: 0.7);
    } catch (e) {
      debugPrint('playHit error: $e');
    }
  }

  void playMiss() {
    HapticFeedback.lightImpact();
    if (!_ready) return;
    try {
      _player?.play(AssetSource('sounds/miss.mp3'), volume: 0.7);
    } catch (e) {
      debugPrint('playMiss error: $e');
    }
  }

  void playClick() => HapticFeedback.selectionClick();

  void dispose() => _player?.dispose();
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SessionTrackingScreen extends StatefulWidget {
  final SessionMode mode;
  final String selectionId;
  final String selectionLabel;
  final int targetShots;

  const SessionTrackingScreen({
    super.key,
    required this.mode,
    required this.selectionId,
    required this.selectionLabel,
    this.targetShots = 25,
  });

  @override
  State<SessionTrackingScreen> createState() => _SessionTrackingScreenState();
}

class _SessionTrackingScreenState extends State<SessionTrackingScreen>
    with TickerProviderStateMixin {
  // ── Stats ─────────────────────────────────────────────────────────────────
  int _made = 0, _swishes = 0, _attempts = 0, _streak = 0, _bestStreak = 0;
  final List<ShotResult> _log = [];

  // ── Timer ─────────────────────────────────────────────────────────────────
  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;

  // ── Services ──────────────────────────────────────────────────────────────
  final _voice = _VoiceEngine();
  final _audio = _AudioManager();
  bool _voiceOn = false;
  bool _voiceListening = false;

  // ── Flash ─────────────────────────────────────────────────────────────────
  String _flashText = '';
  Color _flashColor = AppColors.green;

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _flashCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  late final AnimationController _makePressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final AnimationController _missPressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final AnimationController _swishPressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final AnimationController _voicePulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400))
    ..forward();

  late final Animation<double> _makePressAnim = _buildPressAnim(_makePressCtrl);
  late final Animation<double> _missPressAnim = _buildPressAnim(_missPressCtrl);
  late final Animation<double> _swishPressAnim =
      _buildPressAnim(_swishPressCtrl);

  Animation<double> _buildPressAnim(AnimationController c) =>
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.93), weight: 35),
        TweenSequenceItem(tween: Tween(begin: 0.93, end: 1.03), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 25),
      ]).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));

  // ── Computed ──────────────────────────────────────────────────────────────
  double get _pct => _attempts == 0 ? 0.0 : _made / _attempts;
  String get _pctStr => _attempts == 0 ? '—' : '${(_pct * 100).round()}%';
  int get _missed => _attempts - _made;

  Color get _accuracyColor {
    if (_attempts == 0) return AppColors.text3;
    if (_pct >= 0.70) return AppColors.green;
    if (_pct >= 0.50) return AppColors.gold;
    return AppColors.red;
  }

  String get _timerStr {
    final e = _sw.elapsed;
    final m = e.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = e.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _sw.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _audio.init();
    _initVoice();
  }

  Future<void> _initVoice() async {
    await _voice.init();
    _voice.onCommand = _onVoiceCommand;
    _voice.onStateChange = (listening) {
      if (mounted) setState(() => _voiceListening = listening);
    };
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _voiceOn = false;
    _voice.dispose();
    _audio.dispose();
    _ticker?.cancel();
    _sw.stop();
    _flashCtrl.dispose();
    _makePressCtrl.dispose();
    _missPressCtrl.dispose();
    _swishPressCtrl.dispose();
    _voicePulseCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Voice ─────────────────────────────────────────────────────────────────
  void _toggleVoice() {
    _audio.playClick();
    if (!_voice.available) {
      _flash('MIC NIEDOSTĘPNY', AppColors.red);
      return;
    }

    setState(() => _voiceOn = !_voiceOn);
    if (_voiceOn) {
      _voice.start();
      _flash('VOICE ON', AppColors.gold);
    } else {
      _voice.stop();
      setState(() => _voiceListening = false);
      _flash('VOICE OFF', AppColors.gold);
    }
  }

  void _onVoiceCommand(String cmd) {
    if (!mounted) return;
    switch (cmd) {
      case 'make':
        _recordMake(swish: false);
        break;
      case 'swish':
        _recordMake(swish: true);
        break;
      case 'miss':
        _recordMiss();
        break;
      case 'undo':
        _undo();
        break;
      case 'finish':
        _voiceOn = false;
        _voice.stop();
        _finish();
        break;
    }
  }

  // ── Shots ─────────────────────────────────────────────────────────────────
  void _recordMake({bool swish = false}) {
    _audio.playHit();
    setState(() {
      _made++;
      if (swish) _swishes++;
      _attempts++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      _log.add(swish ? ShotResult.swish : ShotResult.make);
    });
    _flash(
        swish ? '+ SWISH' : '+ MADE', swish ? AppColors.gold : AppColors.green);
    (swish ? _swishPressCtrl : _makePressCtrl).forward(from: 0);
  }

  void _recordMiss() {
    _audio.playMiss();
    setState(() {
      _attempts++;
      _streak = 0;
      _log.add(ShotResult.miss);
    });
    _flash('MISS', AppColors.red);
    _missPressCtrl.forward(from: 0);
  }

  void _undo() {
    if (_log.isEmpty) return;
    _audio.playClick();
    setState(() {
      final last = _log.removeLast();
      _attempts--;
      if (last != ShotResult.miss) {
        _made--;
        if (last == ShotResult.swish) _swishes--;
        _streak = _recomputeStreak();
      }
    });
    _flash('UNDO', AppColors.blue);
  }

  int _recomputeStreak() {
    int s = 0;
    for (final r in _log.reversed) {
      if (r != ShotResult.miss) {
        s++;
      } else {
        break;
      }
    }
    return s;
  }

  void _flash(String text, Color color) {
    if (!mounted) return;
    setState(() {
      _flashText = text;
      _flashColor = color;
    });
    _flashCtrl.forward(from: 0);
  }

  // ── Finish ────────────────────────────────────────────────────────────────
  void _finish() {
    _voiceOn = false;
    _voice.stop();
    _ticker?.cancel();
    _sw.stop();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (_) => _SummarySheet(
        label: widget.selectionLabel,
        mode: widget.mode,
        selectionId: widget.selectionId,
        targetShots: widget.targetShots,
        made: _made,
        swishes: _swishes,
        attempts: _attempts,
        bestStreak: _bestStreak,
        elapsed: _sw.elapsed,
        log: List.unmodifiable(_log),
        onSave: () => Navigator.of(context).popUntil((r) => r.isFirst),
        onDiscard: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
        child: SafeArea(
            child: Column(children: [
          _buildTopBar(),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              const SizedBox(height: 12),
              _buildFlash(),
              const Spacer(flex: 1),
              _buildGauge(),
              const SizedBox(height: 28),
              _buildStats(),
              const Spacer(flex: 2),
              _buildTrend(),
              const Spacer(flex: 3),
              _buildButtons(),
              const SizedBox(height: 14),
              _buildUtilBar(),
              const SizedBox(height: 16),
            ]),
          )),
        ])),
      ),
    );
  }

  Widget _buildTopBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(children: [
          _BackBtn(onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.mode == SessionMode.position ? 'POSITION' : 'RANGE',
                  style: AppText.ui(9,
                      color: AppColors.text3,
                      letterSpacing: 1.8,
                      weight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(widget.selectionLabel,
                  style: AppText.ui(17, weight: FontWeight.w700)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.green)),
              const SizedBox(width: 7),
              Text(_timerStr, style: AppText.ui(13, weight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _finish,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('Finish',
                  style: AppText.ui(13,
                      weight: FontWeight.w700, color: AppColors.bg)),
            ),
          ),
        ]),
      );

  Widget _buildFlash() => SizedBox(
        height: 24,
        child: AnimatedBuilder(
          animation: _flashCtrl,
          builder: (_, __) {
            final t = _flashCtrl.value;
            final opacity =
                (t < 0.55 ? 1.0 : (1.0 - (t - 0.55) / 0.45)).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, -6 * t),
                child: Text(_flashText,
                    style: AppText.ui(15,
                        weight: FontWeight.w800,
                        color: _flashColor,
                        letterSpacing: 1.2)),
              ),
            );
          },
        ),
      );

  Widget _buildGauge() => SizedBox(
        width: 210,
        height: 210,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
              child: CustomPaint(
                  painter: _RingPainter(
                      progress: _attempts == 0 ? 1.0 : _pct,
                      color: _accuracyColor,
                      isEmpty: _attempts == 0))),
          Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _makePressCtrl,
              builder: (_, __) => Transform.scale(
                scale: _makePressAnim.value,
                child: Text(_pctStr,
                    style: AppText.display(54, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 4),
            Text('$_made / $_attempts',
                style: AppText.ui(17,
                    color: AppColors.text2, weight: FontWeight.w600)),
          ]),
        ]),
      );

  Widget _buildStats() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MiniStat(
              label: 'STREAK',
              value: '$_streak',
              icon: Icons.local_fire_department_rounded,
              color: AppColors.gold),
          Container(width: 1, height: 28, color: AppColors.border),
          _MiniStat(
              label: 'BEST',
              value: '$_bestStreak',
              icon: Icons.star_rounded,
              color: AppColors.blue),
          Container(width: 1, height: 28, color: AppColors.border),
          _MiniStat(
              label: 'MISSED',
              value: '$_missed',
              icon: Icons.close_rounded,
              color: AppColors.red),
        ],
      );

  Widget _buildTrend() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('ACCURACY TREND',
                style: AppText.ui(10,
                    color: AppColors.text3,
                    letterSpacing: 1.5,
                    weight: FontWeight.w700)),
            Text('Recent shots', style: AppText.ui(10, color: AppColors.text3)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: _log.isEmpty
                ? Center(
                    child: Text('Awaiting first shot…',
                        style: AppText.ui(13, color: AppColors.text3)))
                : CustomPaint(painter: _TrendPainter(_log, _accuracyColor)),
          ),
          if (_log.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:
                  (_log.length > 20 ? _log.sublist(_log.length - 20) : _log)
                      .map((r) => Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: r == ShotResult.swish
                                ? AppColors.gold
                                : r == ShotResult.make
                                    ? AppColors.green
                                    : AppColors.red.withValues(alpha: 0.6),
                          )))
                      .toList(),
            ),
          ],
        ]),
      );

  Widget _buildButtons() => Row(children: [
        Expanded(
            child: AnimatedBuilder(
          animation: _missPressCtrl,
          builder: (_, __) => Transform.scale(
              scale: _missPressAnim.value,
              child: _ActionBtn(
                  label: 'MISS',
                  icon: Icons.close_rounded,
                  textColor: AppColors.text2,
                  iconColor: AppColors.red,
                  bgColor: AppColors.surface,
                  borderColor: AppColors.border,
                  onTap: _recordMiss)),
        )),
        const SizedBox(width: 12),
        Expanded(
            child: AnimatedBuilder(
          animation: _makePressCtrl,
          builder: (_, __) => Transform.scale(
              scale: _makePressAnim.value,
              child: _ActionBtn(
                  label: 'MAKE',
                  icon: Icons.check_rounded,
                  textColor: AppColors.bg,
                  iconColor: AppColors.bg,
                  bgColor: AppColors.green,
                  borderColor: Colors.transparent,
                  shadowColor: AppColors.green.withValues(alpha: 0.25),
                  onTap: () => _recordMake(swish: false))),
        )),
        const SizedBox(width: 12),
        Expanded(
            child: AnimatedBuilder(
          animation: _swishPressCtrl,
          builder: (_, __) => Transform.scale(
              scale: _swishPressAnim.value,
              child: _ActionBtn(
                  label: 'SWISH',
                  icon: Icons.whatshot_rounded,
                  textColor: AppColors.bg,
                  iconColor: AppColors.bg,
                  bgColor: AppColors.gold,
                  borderColor: Colors.transparent,
                  shadowColor: AppColors.gold.withValues(alpha: 0.25),
                  onTap: () => _recordMake(swish: true))),
        )),
      ]);

  Widget _buildUtilBar() => Row(children: [
        _UtilBtn(
            icon: Icons.undo_rounded,
            label: 'Undo',
            enabled: _log.isNotEmpty,
            onTap: _undo),
        const SizedBox(width: 10),
        Expanded(
            child: GestureDetector(
          onTap: _toggleVoice,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            decoration: BoxDecoration(
              color: _voiceOn
                  ? AppColors.gold.withValues(alpha: 0.10)
                  : AppColors.surface,
              border: Border.all(
                  color: _voiceOn
                      ? AppColors.gold.withValues(alpha: 0.45)
                      : AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_voiceOn && _voiceListening)
                AnimatedBuilder(
                  animation: _voicePulseCtrl,
                  builder: (_, __) => Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold.withValues(
                            alpha: 0.4 + 0.6 * _voicePulseCtrl.value)),
                  ),
                ),
              Icon(
                !_voice.available
                    ? Icons.mic_off_rounded
                    : _voiceListening
                        ? Icons.mic_rounded
                        : Icons.mic_none_rounded,
                size: 18,
                color: !_voice.available
                    ? AppColors.text3
                    : _voiceOn
                        ? AppColors.gold
                        : AppColors.text3,
              ),
              const SizedBox(width: 8),
              Text(
                !_voice.available
                    ? 'Mic niedostępny'
                    : _voiceOn
                        ? (_voiceListening ? 'Słucham…' : 'Wznawiam…')
                        : 'Voice Mode',
                style: AppText.ui(13,
                    weight: FontWeight.w600,
                    color: !_voice.available
                        ? AppColors.text3
                        : _voiceOn
                            ? AppColors.gold
                            : AppColors.text3),
              ),
            ]),
          ),
        )),
        const SizedBox(width: 10),
        _UtilBtn(
          icon: Icons.info_outline_rounded,
          label: 'Tips',
          enabled: true,
          onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => const _VoiceTipsSheet()),
        ),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isEmpty;
  const _RingPainter(
      {required this.progress, required this.color, this.isEmpty = false});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const sw = 15.0;
    final r = size.width / 2 - sw / 2;
    final base = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..color = isEmpty ? AppColors.border : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), 0, math.pi * 2, false, base);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
        math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) =>
      o.progress != progress || o.color != color || o.isEmpty != isEmpty;
}

class _TrendPainter extends CustomPainter {
  final List<ShotResult> log;
  final Color color;
  const _TrendPainter(this.log, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (log.isEmpty) return;
    final pts = <double>[];
    int m = 0;
    for (int i = 0; i < log.length; i++) {
      if (log[i] != ShotResult.miss) m++;
      pts.add(m / (i + 1));
    }
    final step = size.width / math.max(pts.length - 1, 1);
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final x = i * step;
      final y = size.height - pts[i] * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round);
    if (pts.length > 1) {
      final fill = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
          fill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0)
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter o) => o.log.length != log.length;
}

// ─────────────────────────────────────────────────────────────────────────────
//  REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppText.ui(10,
                  color: AppColors.text3,
                  weight: FontWeight.w700,
                  letterSpacing: 1.0)),
        ]),
        const SizedBox(height: 5),
        Text(value, style: AppText.display(22, color: Colors.white)),
      ]);
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color textColor, iconColor, bgColor, borderColor;
  final Color? shadowColor;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.textColor,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 82,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: shadowColor != null
                ? [
                    BoxShadow(
                        color: shadowColor!,
                        blurRadius: 14,
                        offset: const Offset(0, 5))
                  ]
                : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 5),
            Text(label,
                style: AppText.ui(15,
                    weight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 1.4)),
          ]),
        ),
      );
}

class _UtilBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _UtilBtn(
      {required this.icon,
      required this.label,
      required this.enabled,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.3,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: 56,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: AppColors.text2),
              const SizedBox(height: 2),
              Text(label, style: AppText.ui(9, color: AppColors.text3)),
            ]),
          ),
        ),
      );
}

class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 15, color: AppColors.text2),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUMMARY SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _SummarySheet extends StatefulWidget {
  final String label;
  final SessionMode mode;
  final String selectionId;
  final int targetShots;
  final int made, swishes, attempts, bestStreak;
  final Duration elapsed;
  final List<ShotResult> log;
  final VoidCallback onSave, onDiscard;

  const _SummarySheet({
    required this.label,
    required this.mode,
    required this.selectionId,
    required this.targetShots,
    required this.made,
    required this.swishes,
    required this.attempts,
    required this.bestStreak,
    required this.elapsed,
    required this.log,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  State<_SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends State<_SummarySheet> {
  bool _isSaving = false;

  String get _pct => widget.attempts == 0
      ? '0%'
      : '${(widget.made / widget.attempts * 100).round()}%';
  String get _time {
    final m = widget.elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = widget.elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _grade {
    if (widget.attempts == 0) return '—';
    final p = widget.made / widget.attempts;
    if (p >= 0.85) return 'S';
    if (p >= 0.75) return 'A';
    if (p >= 0.65) return 'B';
    if (p >= 0.50) return 'C';
    return 'D';
  }

  Color get _gradeColor {
    if (widget.attempts == 0) return AppColors.text3;
    final p = widget.made / widget.attempts;
    if (p >= 0.75) return AppColors.green;
    if (p >= 0.50) return AppColors.gold;
    return AppColors.red;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final session = Session(
        userId: user.id,
        type: 'live',
        mode: widget.mode == SessionMode.position ? 'position' : 'range',
        selectionId: widget.selectionId,
        selectionLabel: widget.label,
        targetShots: widget.targetShots,
        made: widget.made,
        swishes: widget.swishes,
        attempts: widget.attempts,
        bestStreak: widget.bestStreak,
        elapsedSeconds: widget.elapsed.inSeconds,
      );
      final shots = widget.log
          .asMap()
          .entries
          .map((e) => Shot(
                sessionId: '',
                userId: user.id,
                orderIdx: e.key,
                isMake: e.value != ShotResult.miss,
                isSwish: e.value == ShotResult.swish,
              ))
          .toList();
      await SessionService().saveSessionData(session, shots);
      widget.onSave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 36,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)))),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SESSION COMPLETE',
                    style: AppText.ui(10,
                        color: AppColors.text3,
                        letterSpacing: 1.8,
                        weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(widget.label,
                    style: AppText.ui(22, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.timer_outlined,
                      size: 13, color: AppColors.text3),
                  const SizedBox(width: 5),
                  Text(_time, style: AppText.ui(12, color: AppColors.text3)),
                ]),
              ],
            )),
            Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _gradeColor.withValues(alpha: 0.08),
                  border: Border.all(
                      color: _gradeColor.withValues(alpha: 0.4), width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                    child: Text(_grade,
                        style: AppText.display(34, color: _gradeColor)))),
          ]),
          const SizedBox(height: 22),
          Container(height: 1, color: AppColors.borderSub),
          const SizedBox(height: 18),
          Row(children: [
            _SumTile('MADE', '${widget.made}', AppColors.green),
            _SumTile('SWISHES', '${widget.swishes}', AppColors.gold),
            _SumTile('ACCURACY', _pct, _gradeColor),
            _SumTile('STREAK', '${widget.bestStreak}', AppColors.gold),
          ]),
          if (widget.log.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('SHOT LOG',
                style: AppText.ui(10,
                    color: AppColors.text3,
                    letterSpacing: 1.8,
                    weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
                spacing: 5,
                runSpacing: 5,
                children: widget.log
                    .take(50)
                    .map((r) => Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: r == ShotResult.swish
                                  ? AppColors.gold
                                  : r == ShotResult.make
                                      ? AppColors.green
                                      : AppColors.red),
                        ))
                    .toList()),
            if (widget.log.length > 50) ...[
              const SizedBox(height: 6),
              Text('+ ${widget.log.length - 50} more',
                  style: AppText.ui(10, color: AppColors.text3)),
            ],
          ],
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
                child: GestureDetector(
              onTap: widget.onDiscard,
              child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                      color: AppColors.surfaceHi,
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(
                      child: Text('Discard',
                          style: AppText.ui(14,
                              weight: FontWeight.w700,
                              color: AppColors.text2)))),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: GestureDetector(
              onTap: _isSaving ? null : _save,
              child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: AppColors.bg, strokeWidth: 2.5))
                          : Text('Save Session',
                              style: AppText.ui(14,
                                  weight: FontWeight.w700,
                                  color: AppColors.bg)))),
            )),
          ]),
        ],
      ),
    );
  }
}

class _SumTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SumTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(children: [
        Text(value,
            style: AppText.ui(19, weight: FontWeight.w700, color: color)),
        const SizedBox(height: 3),
        Text(label,
            style: AppText.ui(9, color: AppColors.text3, letterSpacing: 0.8)),
      ]));
}

// ─────────────────────────────────────────────────────────────────────────────
//  VOICE TIPS SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceTipsSheet extends StatelessWidget {
  const _VoiceTipsSheet();

  @override
  Widget build(BuildContext context) {
    const tips = [
      ('"punkt" / "traf" / "wpadł"', 'Trafienie', AppColors.green),
      ('"czysto" / "swish"', 'Swish', AppColors.gold),
      ('"pudło" / "miss" / "chybił"', 'Pudło', AppColors.red),
      ('"cofnij" / "undo" / "anuluj"', 'Cofnij', AppColors.blue),
      ('"koniec" / "stop" / "finish"', 'Koniec sesji', AppColors.text2),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 36,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)))),
          Text('KOMENDY GŁOSOWE',
              style: AppText.ui(10,
                  color: AppColors.text3,
                  letterSpacing: 1.8,
                  weight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.$3.withValues(alpha: 0.1),
                      border: Border.all(color: t.$3.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(t.$1,
                        style: AppText.ui(12,
                            weight: FontWeight.w700, color: t.$3)),
                  ),
                  const SizedBox(width: 12),
                  Text(t.$2, style: AppText.ui(13, color: AppColors.text2)),
                ]),
              )),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                color: AppColors.surfaceHi,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.bolt_rounded, size: 15, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Komendy wyzwalają się natychmiast – bez czekania',
                style: AppText.ui(12, color: AppColors.text3),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}
