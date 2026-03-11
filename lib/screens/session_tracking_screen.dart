// lib/screens/session_tracking_screen.dart
//
// ═══════════════════════════════════════════════════════════════════════════
//  SESSION TRACKING SCREEN
//
//  Odpowiedzialność tego pliku: TYLKO UI.
//  - Uruchamia BackgroundAsrService na początku sesji
//  - Nasłuchuje zdarzeń ze strumienia usługi tła
//  - Wyświetla liczniki, animacje, trend
//  - Obsługuje przyciski dotykowe jako alternatywę dla głosu
//  - ZERO logiki audio i ASR tutaj
//
//  NOWE vs poprzednia wersja:
//  - Subskrypcja AsrEvents.status → debug panel w UI
//  - _serviceReady ustawiany ze statusu serwisu (nie z try/catch toggleVoice)
//  - Długie przytrzymanie przycisku Voice → toggle debug panelu
//  - Panel debug jest automatycznie widoczny gdy serwis rzuci błąd
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../main.dart';
import '../models/session.dart';
import '../models/shot.dart';
import '../services/background_asr_service.dart';
import '../services/session_service.dart';
import '../utils/performance.dart';
import 'session_setup_screen.dart';

enum ShotResult { miss, make, swish }

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN WIDGET
// ═══════════════════════════════════════════════════════════════════════════

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
  // ── Stan sesji ──────────────────────────────────────────────────────────
  int _made = 0, _swishes = 0, _attempts = 0, _streak = 0, _bestStreak = 0;
  final List<ShotResult> _log = [];

  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;

  // ── Stan Voice ──────────────────────────────────────────────────────────
  bool _voiceOn = false; // usługa tła jest aktywna
  bool _voiceActive = false; // VAD właśnie wykrywa mowę (dot-pulse)
  bool _serviceReady = false; // modele załadowane, nasłuchiwanie aktywne

  // ── Debug panel ─────────────────────────────────────────────────────────
  //  Logi z usługi tła – widoczne na urządzeniu bez kabla debugera.
  //  Toggle: długie przytrzymanie przycisku Voice.
  //  Auto-pokaż: przy błędzie serwisu.
  final List<String> _debugLog = [];
  bool _showDebug = false;

  // ── Subskrypcje zdarzeń z usługi tła ────────────────────────────────────
  final List<StreamSubscription> _subs = [];

  // ── Flash feedback ──────────────────────────────────────────────────────
  String _flashText = '';
  Color _flashColor = AppColors.green;

  // ── Animacje ─────────────────────────────────────────────────────────────
  late final AnimationController _flashCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  late final AnimationController _makePressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240));
  late final AnimationController _missPressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240));
  late final AnimationController _swishPressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240));
  late final AnimationController _pulsCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 850))
    ..repeat(reverse: true);
  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380))
    ..forward();

  late final Animation<double> _makeAnim = _pressAnim(_makePressCtrl);
  late final Animation<double> _missAnim = _pressAnim(_missPressCtrl);
  late final Animation<double> _swishAnim = _pressAnim(_swishPressCtrl);

  Animation<double> _pressAnim(AnimationController c) => TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.93), weight: 35),
        TweenSequenceItem(tween: Tween(begin: 0.93, end: 1.03), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 25),
      ]).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));

  // ── Obliczenia ────────────────────────────────────────────────────────────
  double get _pct => _attempts == 0 ? 0.0 : _made / _attempts;
  String get _pctStr => _attempts == 0 ? '—' : '${(_pct * 100).round()}%';
  int get _missed => _attempts - _made;

  Color get _ringColor {
    if (_attempts == 0) return AppColors.text3;
    if (_pct >= 0.70) return AppColors.green;
    if (_pct >= 0.50) return AppColors.gold;
    return AppColors.red;
  }

  String get _timerStr {
    final e = _sw.elapsed;
    return '${e.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${e.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _sw.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _subscribeToService();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _ticker?.cancel();
    _sw.stop();
    _flashCtrl.dispose();
    _makePressCtrl.dispose();
    _missPressCtrl.dispose();
    _swishPressCtrl.dispose();
    _pulsCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SUBSKRYPCJE ZDARZEŃ Z TŁA
  // ═══════════════════════════════════════════════════════════════════════

  void _subscribeToService() {
    // ── Trafienie ──────────────────────────────────────────────────────────
    _subs.add(
      BackgroundAsrService.events(AsrEvents.shotMake).listen((_) {
        if (!mounted) return;
        _applyMake(swish: false);
      }),
    );

    // ── Swish ──────────────────────────────────────────────────────────────
    _subs.add(
      BackgroundAsrService.events(AsrEvents.shotSwish).listen((_) {
        if (!mounted) return;
        _applyMake(swish: true);
      }),
    );

    // ── Pudło ──────────────────────────────────────────────────────────────
    _subs.add(
      BackgroundAsrService.events(AsrEvents.shotMiss).listen((_) {
        if (!mounted) return;
        _applyMiss();
      }),
    );

    // ── Cofnij ─────────────────────────────────────────────────────────────
    _subs.add(
      BackgroundAsrService.events(AsrEvents.shotUndo).listen((_) {
        if (!mounted) return;
        _applyUndo();
      }),
    );

    // ── Koniec ─────────────────────────────────────────────────────────────
    _subs.add(
      BackgroundAsrService.events(AsrEvents.finish).listen((_) {
        if (!mounted) return;
        _finish();
      }),
    );

    // ── Stan VAD (dot-pulse) ───────────────────────────────────────────────
    _subs.add(
      BackgroundAsrService.events(AsrEvents.voiceState).listen((data) {
        if (!mounted) return;
        final active = data?['active'] as bool? ?? false;
        setState(() => _voiceActive = active);
      }),
    );

    // ── Status z serwisu → debug log + _serviceReady ───────────────────────
    //
    //  Każdy krok inicjalizacji serwisu wysyła AsrEvents.status.
    //  Gdy przyjdzie 'Nasłuchuję ✓' → ustawiamy _serviceReady = true
    //  co przełącza UI z "Ładuję…" na "Słucham…"
    //
    _subs.add(
      BackgroundAsrService.events(AsrEvents.status).listen((data) {
        if (!mounted) return;
        final msg = data?['msg'] as String? ?? '';
        setState(() {
          _debugLog.add(msg);
          if (_debugLog.length > 15) _debugLog.removeAt(0);
          if (msg.contains('Nasłuchuję') || msg.contains('Gotowy')) {
            _serviceReady = true;
          }
        });
      }),
    );

    // ── Błędy z serwisu ────────────────────────────────────────────────────
    _subs.add(
      BackgroundAsrService.events(AsrEvents.error).listen((data) {
        if (!mounted) return;
        final msg = data?['message'] as String? ?? 'Unknown error';
        debugPrint('[UI] Błąd serwisu: $msg');
        setState(() {
          _debugLog.add('❌ $msg');
          _showDebug = true; // automatycznie pokaż panel przy błędzie
          _voiceOn = false;
          _serviceReady = false;
          _voiceActive = false;
        });
        _flash('ERROR', AppColors.red);
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  VOICE TOGGLE
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _toggleVoice() async {
    HapticFeedback.selectionClick();

    if (!_voiceOn) {
      setState(() {
        _voiceOn = true;
        _serviceReady = false;
        _debugLog.clear();
        _showDebug = true;
      });
      _flash('VOICE ON', AppColors.gold);

      try {
        await BackgroundAsrService.startSession();
        // _serviceReady jest ustawiany asynchronicznie przez AsrEvents.status
        // gdy serwis wyśle 'Nasłuchuję ✓'
      } catch (e) {
        if (mounted) {
          setState(() {
            _voiceOn = false;
            _serviceReady = false;
          });
          _flash('MIC ERROR', AppColors.red);
        }
      }
    } else {
      await BackgroundAsrService.stopListening();
      if (mounted) {
        setState(() {
          _voiceOn = false;
          _voiceActive = false;
          _serviceReady = false;
        });
        _flash('VOICE OFF', AppColors.gold);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  LOGIKA RZUTÓW
  // ═══════════════════════════════════════════════════════════════════════

  void _applyMake({required bool swish}) {
    HapticFeedback.mediumImpact();
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

  void _applyMiss() {
    HapticFeedback.lightImpact();
    setState(() {
      _attempts++;
      _streak = 0;
      _log.add(ShotResult.miss);
    });
    _flash('MISS', AppColors.red);
    _missPressCtrl.forward(from: 0);
  }

  void _applyUndo() {
    if (_log.isEmpty) return;
    HapticFeedback.selectionClick();
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

  // ═══════════════════════════════════════════════════════════════════════
  //  ZAKOŃCZENIE SESJI
  // ═══════════════════════════════════════════════════════════════════════

  void _finish() {
    _ticker?.cancel();
    _sw.stop();
    BackgroundAsrService.shutdown();
    setState(() {
      _voiceOn = false;
      _voiceActive = false;
      _serviceReady = false;
    });

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

  // ═══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
        child: SafeArea(
          child: Column(children: [
            _topBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  const SizedBox(height: 12),
                  _flashLabel(),
                  const Spacer(flex: 1),
                  _gauge(),
                  const SizedBox(height: 24),
                  _statsRow(),
                  const Spacer(flex: 2),
                  _trend(),
                  const Spacer(flex: 3),
                  // Debug panel – widoczny gdy _showDebug == true
                  if (_showDebug) _debugPanel(),
                  _trackBtns(),
                  const SizedBox(height: 14),
                  _utilBar(),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(children: [
          _BackBtn(onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mode == SessionMode.position ? 'POSITION' : 'RANGE',
                  style: AppText.ui(9,
                      color: AppColors.text3,
                      letterSpacing: 1.8,
                      weight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(widget.selectionLabel,
                    style: AppText.ui(17, weight: FontWeight.w700)),
              ],
            ),
          ),
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

  // ── Flash label ───────────────────────────────────────────────────────────

  Widget _flashLabel() => SizedBox(
        height: 24,
        child: AnimatedBuilder(
          animation: _flashCtrl,
          builder: (_, __) {
            final t = _flashCtrl.value;
            final o =
                (t < 0.55 ? 1.0 : (1.0 - (t - 0.55) / 0.45)).clamp(0.0, 1.0);
            return Opacity(
              opacity: o,
              child: Transform.translate(
                offset: Offset(0, -5 * t),
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

  // ── Gauge ─────────────────────────────────────────────────────────────────

  Widget _gauge() => SizedBox(
        width: 210,
        height: 210,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: CustomPaint(
              painter: _RingPainter(
                  progress: _attempts == 0 ? 1.0 : _pct,
                  color: _ringColor,
                  empty: _attempts == 0),
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _makePressCtrl,
              builder: (_, __) => Transform.scale(
                scale: _makeAnim.value,
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

  // ── Stats row ─────────────────────────────────────────────────────────────

  Widget _statsRow() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MiniStat(
              label: 'STREAK',
              value: '$_streak',
              icon: Icons.local_fire_department_rounded,
              color: AppColors.gold),
          Container(width: 1, height: 26, color: AppColors.border),
          _MiniStat(
              label: 'BEST',
              value: '$_bestStreak',
              icon: Icons.star_rounded,
              color: AppColors.blue),
          Container(width: 1, height: 26, color: AppColors.border),
          _MiniStat(
              label: 'MISSED',
              value: '$_missed',
              icon: Icons.close_rounded,
              color: AppColors.red),
        ],
      );

  // ── Trend ─────────────────────────────────────────────────────────────────

  Widget _trend() => Container(
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
            Text('Recent', style: AppText.ui(10, color: AppColors.text3)),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: _log.isEmpty
                ? Center(
                    child: Text('Awaiting first shot…',
                        style: AppText.ui(13, color: AppColors.text3)))
                : CustomPaint(painter: _TrendPainter(_log, _ringColor)),
          ),
          if (_log.isNotEmpty) ...[
            const SizedBox(height: 12),
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
                                    : AppColors.red.withValues(alpha: 0.55),
                          )))
                      .toList(),
            ),
          ],
        ]),
      );

  // ── Debug Panel ───────────────────────────────────────────────────────────
  //
  //  Pokazuje logi z usługi tła bez potrzeby kabla USB / narzędzi devtools.
  //  - Auto-pokaż przy błędzie serwisu
  //  - Toggle: długie przytrzymanie przycisku Voice
  //  Kolory: czerwony = błąd, zielony = OK/✓, złoty = keyword, szary = info

  Widget _debugPanel() => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF080810),
          border: Border.all(color: const Color(0xFF2A2A3A)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('DEBUG LOG',
                style: TextStyle(
                    color: Color(0xFF444466),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
            GestureDetector(
              onTap: () => setState(() => _showDebug = false),
              child:
                  const Icon(Icons.close, size: 14, color: Color(0xFF444466)),
            ),
          ]),
          const SizedBox(height: 6),
          ..._debugLog.reversed.take(10).map((msg) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  msg,
                  style: TextStyle(
                    color: msg.contains('❌') || msg.contains('BŁĄD')
                        ? const Color(0xFFFF5252)
                        : msg.contains('✓') || msg.contains('OK')
                            ? const Color(0xFF3DD68C)
                            : msg.startsWith('🎤')
                                ? const Color(0xFFD4A843)
                                : const Color(0xFF555570),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              )),
        ]),
      );

  // ── Track buttons ─────────────────────────────────────────────────────────

  Widget _trackBtns() => Row(children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _missPressCtrl,
            builder: (_, __) => Transform.scale(
              scale: _missAnim.value,
              child: _ActionBtn(
                  label: 'MISS',
                  icon: Icons.close_rounded,
                  textColor: AppColors.text2,
                  iconColor: AppColors.red,
                  bg: AppColors.surface,
                  border: AppColors.border,
                  onTap: _applyMiss),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedBuilder(
            animation: _makePressCtrl,
            builder: (_, __) => Transform.scale(
              scale: _makeAnim.value,
              child: _ActionBtn(
                  label: 'MAKE',
                  icon: Icons.check_rounded,
                  textColor: AppColors.bg,
                  iconColor: AppColors.bg,
                  bg: AppColors.green,
                  border: Colors.transparent,
                  shadow: AppColors.green.withValues(alpha: 0.25),
                  onTap: () => _applyMake(swish: false)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedBuilder(
            animation: _swishPressCtrl,
            builder: (_, __) => Transform.scale(
              scale: _swishAnim.value,
              child: _ActionBtn(
                  label: 'SWISH',
                  icon: Icons.whatshot_rounded,
                  textColor: AppColors.bg,
                  iconColor: AppColors.bg,
                  bg: AppColors.gold,
                  border: Colors.transparent,
                  shadow: AppColors.gold.withValues(alpha: 0.25),
                  onTap: () => _applyMake(swish: true)),
            ),
          ),
        ),
      ]);

  // ── Util bar ──────────────────────────────────────────────────────────────

  Widget _utilBar() => Row(children: [
        _UtilBtn(
            icon: Icons.undo_rounded,
            label: 'Undo',
            enabled: _log.isNotEmpty,
            onTap: _applyUndo),
        const SizedBox(width: 10),
        Expanded(child: _voiceButton()),
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

  // ── Voice Button ──────────────────────────────────────────────────────────
  //
  //  Stany:
  //  • !_voiceOn              → szary,  "Voice Mode"
  //  • _voiceOn && !_ready   → złoty,  "Ładuję…"  + spinner
  //  • _voiceOn && _ready    → złoty,  "Słucham…" + pulsujący dot
  //
  //  Długie przytrzymanie → toggle panelu debug

  Widget _voiceButton() => GestureDetector(
        onTap: _toggleVoice,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          setState(() => _showDebug = !_showDebug);
        },
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
            if (_voiceOn && _serviceReady)
              AnimatedBuilder(
                animation: _pulsCtrl,
                builder: (_, __) => AnimatedOpacity(
                  opacity: _voiceActive ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold
                          .withValues(alpha: 0.35 + 0.65 * _pulsCtrl.value),
                    ),
                  ),
                ),
              ),
            if (_voiceOn && !_serviceReady) ...[
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      color: AppColors.gold, strokeWidth: 2.0)),
              const SizedBox(width: 8),
            ] else
              Icon(
                _voiceOn ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 18,
                color: _voiceOn ? AppColors.gold : AppColors.text3,
              ),
            const SizedBox(width: 8),
            Text(
              _voiceOn
                  ? (_serviceReady ? 'Słucham…' : 'Ładuję…')
                  : 'Voice Mode',
              style: AppText.ui(13,
                  weight: FontWeight.w600,
                  color: _voiceOn ? AppColors.gold : AppColors.text3),
            ),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
//  PAINTERS
// ═══════════════════════════════════════════════════════════════════════════

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool empty;
  const _RingPainter(
      {required this.progress, required this.color, required this.empty});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const sw = 15.0;
    final r = size.width / 2 - sw / 2;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = AppColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..color = empty ? AppColors.border : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) =>
      o.progress != progress || o.color != color || o.empty != empty;
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
                color.withValues(alpha: 0.28),
                color.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter o) => o.log.length != log.length;
}

// ═══════════════════════════════════════════════════════════════════════════
//  REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

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
  final Color textColor, iconColor, bg, border;
  final Color? shadow;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.textColor,
      required this.iconColor,
      required this.bg,
      required this.border,
      this.shadow,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 82,
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border, width: 1.5),
              boxShadow: shadow != null
                  ? [
                      BoxShadow(
                          color: shadow!,
                          blurRadius: 14,
                          offset: const Offset(0, 5))
                    ]
                  : null),
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
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: AppColors.text2),
                    const SizedBox(height: 2),
                    Text(label, style: AppText.ui(9, color: AppColors.text3)),
                  ])),
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
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: AppColors.text2)),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
//  SUMMARY SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _SummarySheet extends StatefulWidget {
  final String label;
  final SessionMode mode;
  final String selectionId;
  final int targetShots, made, swishes, attempts, bestStreak;
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
  bool _saving = false;

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
    return PerformanceGuide.gradeFor(widget.made / widget.attempts);
  }

  Color get _gc {
    if (widget.attempts == 0) return AppColors.text3;
    return PerformanceGuide.colorFor(widget.made / widget.attempts);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
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
        setState(() => _saving = false);
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
          borderRadius: BorderRadius.circular(24)),
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
                      Text(_time,
                          style: AppText.ui(12, color: AppColors.text3)),
                    ]),
                  ]),
            ),
            Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: _gc.withValues(alpha: 0.08),
                    border: Border.all(
                        color: _gc.withValues(alpha: 0.4), width: 1.5),
                    borderRadius: BorderRadius.circular(16)),
                child: Center(
                    child:
                        Text(_grade, style: AppText.display(34, color: _gc)))),
          ]),
          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.borderSub),
          const SizedBox(height: 18),
          Row(children: [
            _SumTile('MADE', '${widget.made}', AppColors.green),
            _SumTile('SWISHES', '${widget.swishes}', AppColors.gold),
            _SumTile('ACCURACY', _pct, _gc),
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
                  .toList(),
            ),
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(14)),
                    child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: AppColors.bg, strokeWidth: 2.5))
                            : Text('Save Session',
                                style: AppText.ui(14,
                                    weight: FontWeight.w700,
                                    color: AppColors.bg)))),
              ),
            ),
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
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
//  VOICE TIPS SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _VoiceTipsSheet extends StatelessWidget {
  const _VoiceTipsSheet();

  @override
  Widget build(BuildContext context) {
    const tips = [
      ('"MAKE"', 'Trafienie', AppColors.green),
      ('"SWISH"', 'Swish', AppColors.gold),
      ('"MISS"', 'Pudło', AppColors.red),
      ('"UNDO"', 'Cofnij', AppColors.blue),
      ('"DONE"', 'Koniec sesji', AppColors.text2),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(24)),
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
                        borderRadius: BorderRadius.circular(8)),
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
                      'Komendy po angielsku – model GigaSpeech działa offline, zero chmury',
                      style: AppText.ui(12, color: AppColors.text3))),
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                color: AppColors.surfaceHi,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.touch_app_rounded,
                  size: 15, color: AppColors.text3),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Przytrzymaj przycisk Voice aby zobaczyć log diagnostyczny',
                      style: AppText.ui(12, color: AppColors.text3))),
            ]),
          ),
        ],
      ),
    );
  }
}
