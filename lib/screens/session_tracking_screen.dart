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
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum ShotResult { miss, make, swish }

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
  int _made = 0;
  int _swishes = 0;
  int _attempts = 0;
  int _streak = 0;
  int _bestStreak = 0;
  final List<ShotResult> _log = [];

  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;

  stt.SpeechToText? _speech;

  String _flashText = '';
  Color _flashColor = AppColors.green;
  late final AnimationController _flashCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  late final AnimationController _makePressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final AnimationController _missPressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));

  late final Animation<double> _makePressScale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.94), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.02), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 25),
  ]).animate(CurvedAnimation(parent: _makePressCtrl, curve: Curves.easeOut));

  late final Animation<double> _missPressScale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.94), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.02), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 25),
  ]).animate(CurvedAnimation(parent: _missPressCtrl, curve: Curves.easeOut));

  late final AnimationController _swishPressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));

  late final Animation<double> _swishPressScale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.94), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.02), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 25),
  ]).animate(CurvedAnimation(parent: _swishPressCtrl, curve: Curves.easeOut));

  bool _voiceOn = false;
  late final AnimationController _voiceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450))
    ..forward();

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    bool available = await _speech!.initialize(
      onStatus: (status) {
        if (status == 'done' && _voiceOn) {
          // Keep listening automatically when it stops
          _startListening();
        }
      },
      onError: (error) => debugPrint('Speech Error: $error'),
    );
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    }
  }

  void _startListening() async {
    if (_speech == null || !_speech!.isAvailable) return;
    await _speech!.listen(
      onResult: (result) {
        final words = result.recognizedWords.toLowerCase();
        _processVoiceCommand(words);
      },
      localeId: 'pl_PL', // Polish language for commands
      pauseFor: const Duration(seconds: 2), // Keep phrase short
    );
  }

  void _stopListening() async {
    if (_speech != null) await _speech!.stop();
  }

  void _processVoiceCommand(String text) {
    if (text.isEmpty) return;

    // We only care about the latest word usually, or check if the string contains the keyword
    if (text.contains('punkt')) {
      _stopListening(); // Stop so we don't double trigger, it will restart automatically due to onStatus
      _recordMake(swish: false);
    } else if (text.contains('pudło')) {
      _stopListening();
      _recordMiss();
    } else if (text.contains('czysto')) {
      _stopListening();
      _recordMake(swish: true);
    } else if (text.contains('cofnij')) {
      _stopListening();
      _undo();
    } else if (text.contains('koniec')) {
      _stopListening();
      _finish();
    }
  }

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

  @override
  void initState() {
    super.initState();
    _sw.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _initSpeech();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sw.stop();
    _stopListening();
    _flashCtrl.dispose();
    _makePressCtrl.dispose();
    _missPressCtrl.dispose();
    _swishPressCtrl.dispose();
    _voiceCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _recordMake({bool swish = false}) {
    HapticFeedback.mediumImpact();
    setState(() {
      _made++;
      if (swish) _swishes++;
      _attempts++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      _log.add(swish ? ShotResult.swish : ShotResult.make);
      _flashText = swish ? '+ SWISH' : '+ MADE';
      _flashColor = swish ? AppColors.gold : AppColors.green;
    });
    if (swish) {
      _swishPressCtrl.forward(from: 0);
    } else {
      _makePressCtrl.forward(from: 0);
    }
    _flashCtrl.forward(from: 0);
  }

  void _recordMiss() {
    HapticFeedback.lightImpact();
    setState(() {
      _attempts++;
      _streak = 0;
      _log.add(ShotResult.miss);
      _flashText = 'MISS';
      _flashColor = AppColors.red;
    });
    _missPressCtrl.forward(from: 0);
    _flashCtrl.forward(from: 0);
  }

  void _undo() {
    if (_log.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      final last = _log.removeLast();
      _attempts--;
      if (last == ShotResult.make || last == ShotResult.swish) {
        _made--;
        if (last == ShotResult.swish) _swishes--;
        _streak = _recomputeStreak();
      }
    });
  }

  int _recomputeStreak() {
    int s = 0;
    for (final b in _log.reversed) {
      if (b == ShotResult.make || b == ShotResult.swish) {
        s++;
      } else {
        break;
      }
    }
    return s;
  }

  void _toggleVoice() async {
    HapticFeedback.selectionClick();

    if (!_voiceOn) {
      // turning on
      if (_speech == null) return;
      setState(() => _voiceOn = true);
      _startListening();
    } else {
      // turning off
      setState(() => _voiceOn = false);
      _stopListening();
    }
  }

  void _finish() {
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
          }),
    );
  }

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
                    const SizedBox(height: 16),
                    _flashLabel(),
                    const Spacer(flex: 1),
                    _mainGauge(),
                    const SizedBox(height: 32),
                    _statsRow(),
                    const Spacer(flex: 2),
                    _trendSection(),
                    const Spacer(flex: 3),
                    _trackButtons(),
                    const SizedBox(height: 16),
                    _utilBar(),
                    const SizedBox(height: 16),
                  ]))),
        ])),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
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
              ])),
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
              ])),
          const SizedBox(width: 10),
          GestureDetector(
              onTap: _finish,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('Finish',
                      style: AppText.ui(13,
                          weight: FontWeight.w700, color: AppColors.bg)))),
        ]));
  }

  Widget _flashLabel() {
    return SizedBox(
        height: 24,
        child: AnimatedBuilder(
            animation: _flashCtrl,
            builder: (_, __) {
              final t = _flashCtrl.value;
              final opacity = t < 0.6 ? 1.0 : (1.0 - (t - 0.6) / 0.4);
              return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                      offset: Offset(0, -8 * t),
                      child: Text(_flashText,
                          style: AppText.ui(15,
                              weight: FontWeight.w800,
                              color: _flashColor,
                              letterSpacing: 1.2))));
            }));
  }

  Widget _mainGauge() {
    return SizedBox(
        width: 220,
        height: 220,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
              child: CustomPaint(
                  painter: _AccuracyRingPainter(
                      progress: _attempts == 0 ? 1.0 : _pct,
                      color: _accuracyColor,
                      isEmpty: _attempts == 0))),
          Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
                animation: _makePressCtrl,
                builder: (_, __) => Transform.scale(
                    scale: _makePressScale.value,
                    child: Text(_pctStr,
                        style: AppText.display(56, color: Colors.white)))),
            const SizedBox(height: 4),
            Text('$_made / $_attempts',
                style: AppText.ui(18,
                    color: AppColors.text2, weight: FontWeight.w600)),
          ]),
        ]));
  }

  Widget _statsRow() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _MiniStat(
          label: 'STREAK',
          value: '$_streak',
          icon: Icons.local_fire_department_rounded,
          color: AppColors.gold),
      Container(width: 1, height: 30, color: AppColors.border),
      _MiniStat(
          label: 'BEST',
          value: '$_bestStreak',
          icon: Icons.star_rounded,
          color: AppColors.blue),
      Container(width: 1, height: 30, color: AppColors.border),
      _MiniStat(
          label: 'MISSED',
          value: '$_missed',
          icon: Icons.close_rounded,
          color: AppColors.red),
    ]);
  }

  Widget _trendSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        const SizedBox(height: 24),
        SizedBox(
            height: 55,
            width: double.infinity,
            child: _log.isEmpty
                ? Center(
                    child: Text('Awaiting first shot...',
                        style: AppText.ui(13, color: AppColors.text3)))
                : CustomPaint(
                    painter: _TrendChartPainter(_log, _accuracyColor))),
        const SizedBox(height: 16),
        if (_log.isNotEmpty) _shotDots(),
      ]),
    );
  }

  Widget _shotDots() {
    final recent = _log.length > 20 ? _log.sublist(_log.length - 20) : _log;
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: recent
            .map((m) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: m == ShotResult.swish
                        ? AppColors.gold
                        : (m == ShotResult.make
                            ? AppColors.green
                            : AppColors.red.withValues(alpha: 0.6)))))
            .toList());
  }

  Widget _trackButtons() {
    return Row(children: [
      Expanded(
          child: AnimatedBuilder(
              animation: _missPressCtrl,
              builder: (_, __) => Transform.scale(
                  scale: _missPressScale.value,
                  child: _ActionBtn(
                      label: 'MISS',
                      icon: Icons.close_rounded,
                      textColor: AppColors.text2,
                      iconColor: AppColors.red,
                      bgColor: AppColors.surface,
                      borderColor: AppColors.border,
                      onTap: _recordMiss)))),
      const SizedBox(width: 12),
      Expanded(
          child: AnimatedBuilder(
              animation: _makePressCtrl,
              builder: (_, __) => Transform.scale(
                  scale: _makePressScale.value,
                  child: _ActionBtn(
                      label: 'MAKE',
                      icon: Icons.check_rounded,
                      textColor: AppColors.bg,
                      iconColor: AppColors.bg,
                      bgColor: AppColors.green,
                      borderColor: Colors.transparent,
                      shadowColor: AppColors.green.withValues(alpha: 0.25),
                      onTap: () => _recordMake(swish: false))))),
      const SizedBox(width: 12),
      Expanded(
          child: AnimatedBuilder(
              animation: _swishPressCtrl,
              builder: (_, __) => Transform.scale(
                  scale: _swishPressScale.value,
                  child: _ActionBtn(
                      label: 'SWISH',
                      icon: Icons.whatshot_rounded,
                      textColor: AppColors.bg,
                      iconColor: AppColors.bg,
                      bgColor: AppColors.gold,
                      borderColor: Colors.transparent,
                      shadowColor: AppColors.gold.withValues(alpha: 0.25),
                      onTap: () => _recordMake(swish: true))))),
    ]);
  }

  Widget _utilBar() {
    return Row(children: [
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
                  duration: const Duration(milliseconds: 220),
                  height: 48,
                  decoration: BoxDecoration(
                      color: _voiceOn
                          ? AppColors.gold.withValues(alpha: 0.10)
                          : AppColors.surface,
                      border: Border.all(
                          color: _voiceOn
                              ? AppColors.gold.withValues(alpha: 0.45)
                              : AppColors.border),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_voiceOn)
                          AnimatedBuilder(
                              animation: _voiceCtrl,
                              builder: (_, __) => Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.only(right: 9),
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.gold.withValues(
                                          alpha: 0.45 +
                                              0.55 * _voiceCtrl.value)))),
                        Icon(
                            _voiceOn
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            size: 18,
                            color: _voiceOn ? AppColors.gold : AppColors.text3),
                        const SizedBox(width: 8),
                        Text(_voiceOn ? 'Listening…' : 'Voice Mode',
                            style: AppText.ui(13,
                                weight: FontWeight.w600,
                                color: _voiceOn
                                    ? AppColors.gold
                                    : AppColors.text3)),
                      ])))),
      const SizedBox(width: 10),
      _UtilBtn(
          icon: Icons.info_outline_rounded,
          label: 'Tips',
          enabled: true,
          onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => const _VoiceTipsSheet())),
    ]);
  }
}

// ── Painters & sub-widgets ───────────────────────────────────────────────────

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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppText.ui(10,
                  color: AppColors.text3,
                  weight: FontWeight.w700,
                  letterSpacing: 1.0))
        ]),
        const SizedBox(height: 6),
        Text(value, style: AppText.display(24, color: Colors.white)),
      ]);
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color textColor, iconColor, bgColor, borderColor;
  final Color? shadowColor;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.textColor,
      required this.iconColor,
      required this.bgColor,
      required this.borderColor,
      this.shadowColor,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          height: 85,
          decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: shadowColor != null
                  ? [
                      BoxShadow(
                          color: shadowColor!,
                          blurRadius: 15,
                          offset: const Offset(0, 6))
                    ]
                  : null),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(height: 6),
            Text(label,
                style: AppText.ui(16,
                    weight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 1.5)),
          ])));
}

class _AccuracyRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isEmpty;
  const _AccuracyRingPainter(
      {required this.progress, required this.color, this.isEmpty = false});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    const sw = 16.0;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - sw / 2),
        0,
        2 * math.pi,
        false,
        Paint()
          ..color = AppColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - sw / 2),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = isEmpty ? AppColors.border : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _AccuracyRingPainter o) =>
      o.progress != progress || o.color != color || o.isEmpty != isEmpty;
}

class _TrendChartPainter extends CustomPainter {
  final List<ShotResult> log;
  final Color themeColor;
  const _TrendChartPainter(this.log, this.themeColor);
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
          ..color = themeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
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
                  themeColor.withValues(alpha: 0.35),
                  themeColor.withValues(alpha: 0)
                ]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter o) =>
      o.log.length != log.length;
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
              width: 58,
              height: 48,
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 19, color: AppColors.text2),
                    const SizedBox(height: 2),
                    Text(label, style: AppText.ui(9, color: AppColors.text3))
                  ]))));
}

// ── Summary sheet ────────────────────────────────────────────────────────────

class _SummarySheet extends StatefulWidget {
  final String label;
  final SessionMode mode;
  final String selectionId;
  final int targetShots;
  final int made, swishes, attempts, bestStreak;
  final Duration elapsed;
  final List<ShotResult> log;
  final VoidCallback onSave, onDiscard;

  const _SummarySheet(
      {required this.label,
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
      required this.onDiscard});

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

  Future<void> _saveData() async {
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

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

      final shots = widget.log.asMap().entries.map((e) {
        return Shot(
          sessionId: '', // assigned in service
          userId: user.id,
          orderIdx: e.key,
          isMake: e.value == ShotResult.make || e.value == ShotResult.swish,
          isSwish: e.value == ShotResult.swish,
        );
      }).toList();

      await SessionService().saveSessionData(session, shots);
      widget.onSave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save session: ${e.toString()}')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(26),
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
                      width: 38,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 26),
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
                            style: AppText.ui(12, color: AppColors.text3))
                      ]),
                    ])),
                Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                        color: _gradeColor.withValues(alpha: 0.08),
                        border: Border.all(
                            color: _gradeColor.withValues(alpha: 0.40),
                            width: 1.5),
                        borderRadius: BorderRadius.circular(16)),
                    child: Center(
                        child: Text(_grade,
                            style: AppText.display(36, color: _gradeColor)))),
              ]),
              const SizedBox(height: 24),
              Container(height: 1, color: AppColors.borderSub),
              const SizedBox(height: 20),
              Row(children: [
                _SumTile('MADE', '${widget.made}', AppColors.green),
                _SumTile('SWISHES', '${widget.swishes}', AppColors.gold),
                _SumTile('ACCURACY', _pct, _gradeColor),
                _SumTile('STREAK', '${widget.bestStreak}', AppColors.gold)
              ]),
              if (widget.log.isNotEmpty) ...[
                const SizedBox(height: 22),
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
                        .map((m) => Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: m == ShotResult.swish
                                    ? AppColors.gold
                                    : (m == ShotResult.make
                                        ? AppColors.green
                                        : AppColors.red))))
                        .toList()),
                if (widget.log.length > 50) ...[
                  const SizedBox(height: 8),
                  Text('+ ${widget.log.length - 50} more',
                      style: AppText.ui(10, color: AppColors.text3)),
                ]
              ],
              const SizedBox(height: 32),
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
                                        color: AppColors.text2)))))),
                const SizedBox(width: 14),
                Expanded(
                    child: GestureDetector(
                        onTap: _isSaving ? null : _saveData,
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
                                            color: AppColors.bg,
                                            strokeWidth: 2.5),
                                      )
                                    : Text('Save Session',
                                        style: AppText.ui(14,
                                            weight: FontWeight.w700,
                                            color: AppColors.bg)))))),
              ]),
            ]));
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
            style: AppText.ui(20, weight: FontWeight.w700, color: color)),
        const SizedBox(height: 3),
        Text(label,
            style: AppText.ui(9, color: AppColors.text3, letterSpacing: 0.8))
      ]));
}

class _VoiceTipsSheet extends StatelessWidget {
  const _VoiceTipsSheet();
  @override
  Widget build(BuildContext context) {
    const tips = [
      ('"punkt"', 'Records a make', AppColors.green),
      ('"czysto"', 'Records a swish', AppColors.gold),
      ('"pudło"', 'Records a miss', AppColors.red),
      ('"cofnij"', 'Undoes last shot', AppColors.text2),
      ('"koniec"', 'Ends the session', AppColors.blue)
    ];
    return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(26),
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
                      width: 38,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 22),
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2)))),
              Text('VOICE COMMANDS',
                  style: AppText.ui(10,
                      color: AppColors.text3,
                      letterSpacing: 1.8,
                      weight: FontWeight.w700)),
              const SizedBox(height: 18),
              ...tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                            style: AppText.ui(13,
                                weight: FontWeight.w700, color: t.$3))),
                    const SizedBox(width: 14),
                    Text(t.$2, style: AppText.ui(14, color: AppColors.text2)),
                  ]))),
              const SizedBox(height: 4),
            ]));
  }
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
              size: 15, color: AppColors.text2)));
}
