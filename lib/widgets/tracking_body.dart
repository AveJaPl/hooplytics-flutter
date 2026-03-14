// lib/widgets/tracking_body.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/shot.dart';
import '../services/background_asr_service.dart';
import '../utils/haptics.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  TRACKING RESULT
// ═══════════════════════════════════════════════════════════════════════════

class TrackingResult {
  final int made, swishes, airballs, attempts, bestStreak;
  final Duration elapsed;
  final List<ShotResult> log;

  const TrackingResult({
    required this.made,
    required this.swishes,
    required this.airballs,
    required this.attempts,
    required this.bestStreak,
    required this.elapsed,
    required this.log,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  TRACKING BODY WIDGET
//
//  Reusable stateful tracking UI.
//  - Handles all shot recording logic and animations
//  - Calls onFinished(TrackingResult) when session ends
//  - Calls onBack() if finished with 0 attempts
//  - Voice service is optional (voiceEnabled)
//  - Swish button is optional (swishEnabled)
//  - Auto-finishes at autoFinishAt shots (for duel/game modes)
// ═══════════════════════════════════════════════════════════════════════════

class TrackingBody extends StatefulWidget {
  final String title;
  final String subtitle;

  /// Accent color for MADE button & finish button. null = AppColors.gold
  final Color? accentColor;
  final bool voiceEnabled;
  final bool swishEnabled;
  final bool airballEnabled;

  /// Auto-call onFinished when attempts reach this value
  final int? autoFinishAt;

  final VoidCallback onBack;
  final void Function(TrackingResult result) onFinished;

  const TrackingBody({
    super.key,
    required this.title,
    required this.subtitle,
    this.accentColor,
    this.voiceEnabled = true,
    this.swishEnabled = true,
    this.airballEnabled = false,
    this.autoFinishAt,
    required this.onBack,
    required this.onFinished,
  });

  @override
  State<TrackingBody> createState() => _TrackingBodyState();
}

class _TrackingBodyState extends State<TrackingBody>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  int _made = 0, _swishes = 0, _airballs = 0, _attempts = 0, _streak = 0, _bestStreak = 0;
  final List<ShotResult> _log = [];
  bool _finished = false;

  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;

  // ── Voice ──────────────────────────────────────────────────────────────────
  bool _voiceOn = false;
  bool _voiceActive = false;
  bool _serviceReady = false;
  final List<StreamSubscription> _subs = [];

  // ── Flash ──────────────────────────────────────────────────────────────────
  String _flashText = '';
  Color _flashColor = AppColors.green;

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _flashCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  late final AnimationController _makePressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240));
  late final AnimationController _missPressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240));
  late final AnimationController _swishPressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240));
  late final AnimationController _airballPressCtrl = AnimationController(
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
  late final Animation<double> _airballAnim = _pressAnim(_airballPressCtrl);

  Animation<double> _pressAnim(AnimationController c) =>
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.93), weight: 35),
        TweenSequenceItem(tween: Tween(begin: 0.93, end: 1.03), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 25),
      ]).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));

  // ── Computed ───────────────────────────────────────────────────────────────
  double get _pct => _attempts == 0 ? 0.0 : _made / _attempts;
  String get _pctStr => _attempts == 0 ? '—' : '${(_pct * 100).round()}%';
  int get _missed => _attempts - _made;

  Color get _ringColor {
    if (_attempts == 0) return AppColors.text3;
    if (_pct >= 0.70) return AppColors.green;
    if (_pct >= 0.50) return AppColors.gold;
    return AppColors.red;
  }

  Color get _accentColor => widget.accentColor ?? AppColors.gold;

  String get _timerStr {
    final e = _sw.elapsed;
    return '${e.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${e.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _sw.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (widget.voiceEnabled) _subscribeToService();
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
    _airballPressCtrl.dispose();
    _pulsCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Voice subscriptions ────────────────────────────────────────────────────

  void _subscribeToService() {
    _subs.add(BackgroundAsrService.events(AsrEvents.shotMake).listen((_) {
      if (!mounted) return;
      _applyMake(swish: false);
    }));
    _subs.add(BackgroundAsrService.events(AsrEvents.shotSwish).listen((_) {
      if (!mounted) return;
      if (widget.swishEnabled) _applyMake(swish: true);
    }));
    _subs.add(BackgroundAsrService.events(AsrEvents.shotMiss).listen((_) {
      if (!mounted) return;
      _applyMiss();
    }));
    _subs.add(BackgroundAsrService.events(AsrEvents.shotUndo).listen((_) {
      if (!mounted) return;
      _applyUndo();
    }));
    _subs.add(BackgroundAsrService.events(AsrEvents.finish).listen((_) {
      if (!mounted) return;
      _finish();
    }));
    _subs.add(
        BackgroundAsrService.events(AsrEvents.voiceState).listen((data) {
      if (!mounted) return;
      final active = data?['active'] as bool? ?? false;
      setState(() => _voiceActive = active);
    }));
    _subs.add(BackgroundAsrService.events(AsrEvents.status).listen((data) {
      if (!mounted) return;
      final msg = data?['msg'] as String? ?? '';
      if (msg.contains('Nasłuchuję') || msg.contains('Gotowy')) {
        setState(() => _serviceReady = true);
      }
    }));
    _subs.add(BackgroundAsrService.events(AsrEvents.error).listen((data) {
      if (!mounted) return;
      setState(() {
        _voiceOn = false;
        _serviceReady = false;
        _voiceActive = false;
      });
      _flashFn('ERROR', AppColors.red);
    }));
  }

  // ── Voice toggle ───────────────────────────────────────────────────────────

  Future<void> _toggleVoice() async {
    Haptics.selectionClick();
    if (!_voiceOn) {
      setState(() {
        _voiceOn = true;
        _serviceReady = false;
      });
      _flashFn('VOICE ON', AppColors.gold);
      try {
        await BackgroundAsrService.startSession();
      } catch (e) {
        if (mounted) {
          setState(() {
            _voiceOn = false;
            _serviceReady = false;
          });
          _flashFn('MIC ERROR', AppColors.red);
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
        _flashFn('VOICE OFF', AppColors.gold);
      }
    }
  }

  // ── Shot logic ─────────────────────────────────────────────────────────────

  void _applyMake({required bool swish}) {
    if (_finished) return;
    Haptics.mediumImpact();
    setState(() {
      _made++;
      if (swish) _swishes++;
      _attempts++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      _log.add(swish ? ShotResult.swish : ShotResult.make);
    });
    _flashFn(
        swish ? '+ SWISH' : '+ MADE', AppColors.green);
    (swish ? _swishPressCtrl : _makePressCtrl).forward(from: 0);
    _checkAutoFinish();
  }

  void _applyMiss() {
    if (_finished) return;
    Haptics.lightImpact();
    setState(() {
      _attempts++;
      _streak = 0;
      _log.add(ShotResult.miss);
    });
    _flashFn('MISS', AppColors.red);
    _missPressCtrl.forward(from: 0);
    _checkAutoFinish();
  }

  void _applyAirball() {
    if (_finished) return;
    Haptics.lightImpact();
    setState(() {
      _attempts++;
      _airballs++;
      _streak = 0;
      _log.add(ShotResult.airball);
    });
    _flashFn('AIRBALL', AppColors.red);
    _airballPressCtrl.forward(from: 0);
    _checkAutoFinish();
  }

  void _applyUndo() {
    if (_finished) return;
    if (_log.isEmpty) return;
    Haptics.selectionClick();
    setState(() {
      final last = _log.removeLast();
      _attempts--;
      if (last == ShotResult.make || last == ShotResult.swish) {
        _made--;
        if (last == ShotResult.swish) _swishes--;
      }
      if (last == ShotResult.airball) _airballs--;
      _streak = _recomputeStreak();
    });
    _flashFn('UNDO', AppColors.blue);
  }

  void _checkAutoFinish() {
    if (widget.autoFinishAt != null &&
        _attempts >= widget.autoFinishAt! &&
        !_finished) {
      // Set immediately to block any further shots during the animation delay
      setState(() => _finished = true);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _finishInternal();
      });
    }
  }

  int _recomputeStreak() {
    int s = 0;
    for (final r in _log.reversed) {
      if (r == ShotResult.make || r == ShotResult.swish) {
        s++;
      } else {
        break;
      }
    }
    return s;
  }

  void _flashFn(String text, Color color) {
    if (!mounted) return;
    setState(() {
      _flashText = text;
      _flashColor = color;
    });
    _flashCtrl.forward(from: 0);
  }

  // ── Finish ─────────────────────────────────────────────────────────────────

  void _finish() {
    if (_finished) return;
    setState(() => _finished = true);
    _finishInternal();
  }

  void _finishInternal() {
    _ticker?.cancel();
    _sw.stop();
    if (widget.voiceEnabled) BackgroundAsrService.shutdown();
    if (!mounted) return;
    setState(() {
      _voiceOn = false;
      _voiceActive = false;
      _serviceReady = false;
    });

    if (_attempts == 0) {
      widget.onBack();
      return;
    }

    widget.onFinished(TrackingResult(
      made: _made,
      swishes: _swishes,
      airballs: _airballs,
      attempts: _attempts,
      bestStreak: _bestStreak,
      elapsed: _sw.elapsed,
      log: List.unmodifiable(_log),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
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
              _trackBtns(),
              const SizedBox(height: 14),
              _utilBar(),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(children: [
          _BackBtn(onTap: widget.onBack),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subtitle,
                  style: AppText.ui(9,
                      color: AppColors.text3,
                      letterSpacing: 1.8,
                      weight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(widget.title,
                    style: AppText.ui(17, weight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
              Text(_timerStr,
                  style: AppText.ui(13, weight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _finish,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('Finish',
                  style: AppText.ui(13,
                      weight: FontWeight.w700, color: AppColors.bg)),
            ),
          ),
        ]),
      );

  // ── Flash label ────────────────────────────────────────────────────────────

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

  // ── Gauge ──────────────────────────────────────────────────────────────────

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

  // ── Stats row ──────────────────────────────────────────────────────────────

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

  // ── Trend ──────────────────────────────────────────────────────────────────

  Widget _trend() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                                ? AppColors.green
                                : r == ShotResult.airball
                                    ? AppColors.red
                                    : Colors.transparent,
                            border: Border.all(
                              color: (r == ShotResult.make || r == ShotResult.swish)
                                  ? AppColors.green
                                  : AppColors.red,
                              width: 1.5,
                            ),
                          )))
                      .toList(),
            ),
          ],
        ]),
      );

  // ── Track buttons ──────────────────────────────────────────────────────────

  Widget _trackBtns() => Row(children: [
        if (widget.airballEnabled) ...[
          Expanded(
            child: AnimatedBuilder(
              animation: _airballPressCtrl,
              builder: (_, __) => Transform.scale(
                scale: _airballAnim.value,
                child: _ActionBtn(
                    label: 'AIRBALL',
                    icon: Icons.air_rounded,
                    textColor: AppColors.bg,
                    iconColor: AppColors.bg,
                    bg: AppColors.red,
                    border: Colors.transparent,
                    shadow: AppColors.red.withValues(alpha: 0.25),
                    onTap: _applyAirball),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: AnimatedBuilder(
            animation: _missPressCtrl,
            builder: (_, __) => Transform.scale(
              scale: _missAnim.value,
              child: _ActionBtn(
                  label: 'MISS',
                  icon: Icons.close_rounded,
                  textColor: AppColors.red,
                  iconColor: AppColors.red,
                  bg: Colors.transparent,
                  border: AppColors.red,
                  onTap: _applyMiss),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedBuilder(
            animation: _makePressCtrl,
            builder: (_, __) => Transform.scale(
              scale: _makeAnim.value,
              child: _ActionBtn(
                  label: 'MADE',
                  icon: Icons.check_circle_outline_rounded,
                  textColor: AppColors.green,
                  iconColor: AppColors.green,
                  bg: Colors.transparent,
                  border: AppColors.green,
                  onTap: () => _applyMake(swish: false)),
            ),
          ),
        ),
        if (widget.swishEnabled) ...[
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedBuilder(
              animation: _swishPressCtrl,
              builder: (_, __) => Transform.scale(
                scale: _swishAnim.value,
                child: _ActionBtn(
                    label: 'SWISH',
                    icon: Icons.auto_awesome_rounded,
                    textColor: AppColors.bg,
                    iconColor: AppColors.bg,
                    bg: AppColors.green,
                    border: Colors.transparent,
                    shadow: AppColors.green.withValues(alpha: 0.25),
                    onTap: () => _applyMake(swish: true)),
              ),
            ),
          ),
        ],
      ]);

  // ── Util bar ───────────────────────────────────────────────────────────────

  Widget _utilBar() => Row(children: [
        _UtilBtn(
            icon: Icons.undo_rounded,
            label: 'Undo',
            enabled: _log.isNotEmpty,
            onTap: _applyUndo),
        if (widget.voiceEnabled) ...[
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
        ],
      ]);

  // ── Voice Button ───────────────────────────────────────────────────────────

  Widget _voiceButton() => GestureDetector(
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
          child:
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                      color: AppColors.gold.withValues(
                          alpha: 0.35 + 0.65 * _pulsCtrl.value),
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
      if (log[i] == ShotResult.make || log[i] == ShotResult.swish) m++;
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
          child:
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                    Text(label,
                        style: AppText.ui(9, color: AppColors.text3)),
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
//  VOICE TIPS SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _VoiceTipsSheet extends StatelessWidget {
  const _VoiceTipsSheet();

  @override
  Widget build(BuildContext context) {
    const tips = [
      ('"MAKE"', 'Trafienie', AppColors.gold),
      ('"SWISH"', 'Swish', AppColors.green),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: t.$3.withValues(alpha: 0.1),
                        border:
                            Border.all(color: t.$3.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(t.$1,
                        style: AppText.ui(12,
                            weight: FontWeight.w700, color: t.$3)),
                  ),
                  const SizedBox(width: 12),
                  Text(t.$2,
                      style: AppText.ui(13, color: AppColors.text2)),
                ]),
              )),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                color: AppColors.surfaceHi,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.bolt_rounded,
                  size: 15, color: AppColors.gold),
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
