import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import '../utils/haptics.dart';
import '../models/session.dart';
import '../models/shot.dart';
import '../services/session_service.dart';
import '../utils/performance.dart';
// ═════════════════════════════════════════════════════════════════════════════
//  THREE POINT CONTEST SCREEN
//  5 racks × 5 balls. Last ball of each rack = money ball (worth 2 pts).
//  60 second timer. Tap MAKE/MISS to advance through balls.
// ═════════════════════════════════════════════════════════════════════════════

enum _BallState { pending, made, missed }

class ThreePointContestScreen extends StatefulWidget {
  const ThreePointContestScreen({super.key});
  @override
  State<ThreePointContestScreen> createState() =>
      _ThreePointContestScreenState();
}

class _ThreePointContestScreenState extends State<ThreePointContestScreen>
    with TickerProviderStateMixin {
  // ── game state ────────────────────────────────────────────────────────────
  static const _rackNames = [
    'Left\nCorner',
    'Left\nWing',
    'Top\nArc',
    'Right\nWing',
    'Right\nCorner'
  ];
  static const _totalRacks = 5;
  static const _ballsPerRack = 5;
  static const _gameDuration = 60;

  // [rack][ball] = _BallState
  late List<List<_BallState>> _balls;

  int _currentRack = 0;
  int _currentBall = 0;
  bool _isSetup = true;
  bool _gameStarted = false;
  bool _gameOver = false;
  int _moneyRackIndex = 4; // Default to Right Corner

  int get _score {
    int s = 0;
    for (int r = 0; r < _totalRacks; r++) {
      for (int b = 0; b < _ballsPerRack; b++) {
        if (_balls[r][b] == _BallState.made) {
          final isMoney = (r == _moneyRackIndex) || (b == 4);
          s += isMoney ? 2 : 1;
        }
      }
    }
    return s;
  }

  int get _maxScore =>
      ((_totalRacks - 1) * (_ballsPerRack - 1 + 2)) + (_ballsPerRack * 2);
  // 4 regular racks (4*1 + 1*2 = 6 pts each) = 24
  // 1 money rack (5*2 = 10 pts) = 10
  // Total = 34

  int get _made {
    int m = 0;
    for (final rack in _balls) {
      for (final b in rack) {
        if (b == _BallState.made) m++;
      }
    }
    return m;
  }

  List<int> get _rackScores {
    List<int> scores = [];
    for (int r = 0; r < _totalRacks; r++) {
      int s = 0;
      for (int b = 0; b < _ballsPerRack; b++) {
        if (_balls[r][b] == _BallState.made) {
          final isMoney = (r == _moneyRackIndex) || (b == 4);
          s += isMoney ? 2 : 1;
        }
      }
      scores.add(s);
    }
    return scores;
  }

  // ── timer ─────────────────────────────────────────────────────────────────
  int _secondsLeft = _gameDuration;
  Timer? _timer;

  // ── animations ────────────────────────────────────────────────────────────
  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450))
    ..forward();
  late final AnimationController _makeBounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  late final AnimationController _rackSwitch = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));

  late final Animation<double> _makeScale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 0.96), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0), weight: 30),
  ]).animate(CurvedAnimation(parent: _makeBounce, curve: Curves.easeOut));

  // ── flash ─────────────────────────────────────────────────────────────────
  String _flashText = '';
  Color _flashColor = AppColors.green;
  late final AnimationController _flashCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void initState() {
    super.initState();
    _resetBalls();
  }

  void _resetBalls() {
    _balls = List.generate(
        _totalRacks, (_) => List.filled(_ballsPerRack, _BallState.pending));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entry.dispose();
    _makeBounce.dispose();
    _rackSwitch.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  // ── timer logic ───────────────────────────────────────────────────────────

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) _endGame();
      });
    });
  }

  void _endGame() {
    _timer?.cancel();
    setState(() {
      _gameOver = true;
    });

    if (_currentRack == 0 && _currentBall == 0) {
      Navigator.of(context).pop();
      return;
    }

    _saveSession();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _showResult();
    });
  }

  Future<void> _saveSession() async {
    try {
      List<Shot> shots = [];
      int order = 0;
      for (int r = 0; r < _totalRacks; r++) {
        for (int b = 0; b < _ballsPerRack; b++) {
          final state = _balls[r][b];
          if (state != _BallState.pending) {
            shots.add(Shot(
              sessionId: '',
              userId: '',
              orderIdx: order++,
              isMake: state == _BallState.made,
              isSwish: false,
              createdAt: DateTime.now(),
            ));
          }
        }
      }

      final session = Session(
        userId: '',
        type: 'game',
        mode: 'range',
        selectionId: 'three_point_contest',
        selectionLabel: '3-Point Contest',
        gameModeId: 'three_point_contest',
        gameData: {
          'score': _score,
          'maxScore': _maxScore,
          'made': _made,
          'rackScores': _rackScores,
        },
        targetShots: _totalRacks * _ballsPerRack,
        made: _made,
        swishes: 0,
        attempts: shots.length,
        bestStreak: 0,
        elapsedSeconds: _gameDuration - _secondsLeft,
      );

      await SessionService().saveSessionData(session, shots);
    } catch (e) {
      debugPrint('Failed to save 3-point contest: $e');
    }
  }

  // ── shot recording ────────────────────────────────────────────────────────

  void _record(bool made) {
    if (_gameOver) return;
    if (!_gameStarted) {
      setState(() => _gameStarted = true);
      _startTimer();
    }
    if (_currentRack >= _totalRacks) return;

    Haptics.mediumImpact();

    final isMoney = (_currentRack == _moneyRackIndex) || (_currentBall == 4);

    setState(() {
      _balls[_currentRack][_currentBall] =
          made ? _BallState.made : _BallState.missed;
      _flashText = made ? (isMoney ? '+2 MONEY!' : '+1 MADE') : 'MISS';
      _flashColor =
          made ? (isMoney ? AppColors.gold : AppColors.green) : AppColors.red;

      // Advance
      _currentBall++;
      if (_currentBall >= _ballsPerRack) {
        _currentBall = 0;
        _currentRack++;
        if (_currentRack >= _totalRacks) _endGame();
      }
    });

    if (made) _makeBounce.forward(from: 0);
    _flashCtrl.forward(from: 0);
  }

  // ── result sheet ──────────────────────────────────────────────────────────

  void _showResult() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _ResultSheet(
        score: _score,
        maxScore: _maxScore,
        made: _made,
        onRetry: () {
          Navigator.pop(context);
          _restart();
        },
        onDone: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    );
  }

  void _restart() {
    setState(() {
      _resetBalls();
      _currentRack = 0;
      _currentBall = 0;
      _isSetup = true;
      _gameStarted = false;
      _gameOver = false;
      _secondsLeft = _gameDuration;
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final timerColor = _secondsLeft <= 10
        ? AppColors.red
        : (_secondsLeft <= 20 ? AppColors.gold : AppColors.text1);
    final progress = _secondsLeft / _gameDuration;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _entry, curve: Curves.easeOut),
        child: SafeArea(
          child: _isSetup
              ? _buildSetup()
              : Column(children: [
                  _topBar(timerColor, progress),
                  const SizedBox(height: 8),
                  _flash(),
                  const SizedBox(height: 10),
                  _scoreDisplay(),
                  const SizedBox(height: 20),
                  _rackDisplay(),
                  const Spacer(),
                  _currentRackLabel(),
                  const SizedBox(height: 20),
                  _actionButtons(),
                  const SizedBox(height: 24),
                ]),
        ),
      ),
    );
  }

  // ── setup phase ───────────────────────────────────────────────────────────

  Widget _buildSetup() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          _SmBtn(
              icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('3-POINT CONTEST',
                    style: AppText.ui(9,
                        color: AppColors.text3,
                        letterSpacing: 1.8,
                        weight: FontWeight.w700)),
                Text('Setup', style: AppText.ui(24, weight: FontWeight.w800)),
              ])),
        ]),
      ),
      const Spacer(flex: 2),
      Text('Select Your Money Rack',
          style:
              AppText.ui(16, color: AppColors.text1, weight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('All 5 balls on this rack will be worth 2 points.',
          style: AppText.ui(13, color: AppColors.text3),
          textAlign: TextAlign.center),
      const SizedBox(height: 32),

      // Rack selection UI
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_totalRacks, (r) {
            final isSelected = r == _moneyRackIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  Haptics.heavyImpact();
                  setState(() => _moneyRackIndex = r);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.gold.withValues(alpha: 0.15)
                          : AppColors.surface,
                      border: Border.all(
                          color: isSelected
                              ? AppColors.gold.withValues(alpha: 0.8)
                              : AppColors.border,
                          width: isSelected ? 2 : 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(children: [
                      // 5 balls
                      ...List.generate(_ballsPerRack, (b) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Container(
                            width: double.infinity,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.gold
                                  : (b == 4
                                      ? AppColors.gold.withValues(alpha: 0.5)
                                      : AppColors.borderSub),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        );
                      }).reversed,
                      const SizedBox(height: 8),
                      Text('R${r + 1}',
                          style: AppText.ui(9,
                              color:
                                  isSelected ? AppColors.gold : AppColors.text3,
                              weight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
      const Spacer(flex: 3),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _BigBtn(
            label: 'START CONTEST',
            icon: Icons.play_arrow_rounded,
            bg: AppColors.gold,
            fg: AppColors.bg,
            iconColor: AppColors.bg,
            border: Colors.transparent,
            glow: true,
            onTap: () {
              Haptics.lightImpact();
              setState(() => _isSetup = false);
            }),
      ),
      const SizedBox(height: 24),
    ]);
  }

  // ── top bar ───────────────────────────────────────────────────────────────

  Widget _topBar(Color timerColor, double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(children: [
        Row(children: [
          _SmBtn(
              icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('3-POINT CONTEST',
                    style: AppText.ui(9,
                        color: AppColors.text3,
                        letterSpacing: 1.8,
                        weight: FontWeight.w700)),
                Text('NBA All-Star Style',
                    style: AppText.ui(15, weight: FontWeight.w700)),
              ])),
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _secondsLeft <= 10
                  ? AppColors.red.withValues(alpha: 0.12)
                  : AppColors.surface,
              border: Border.all(
                  color: _secondsLeft <= 10
                      ? AppColors.red.withValues(alpha: 0.5)
                      : AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.timer_rounded, size: 14, color: timerColor),
              const SizedBox(width: 6),
              Text('${_secondsLeft}s',
                  style: AppText.display(20, color: timerColor)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        // Timer bar
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.borderSub,
            valueColor: AlwaysStoppedAnimation(
                _secondsLeft <= 10 ? AppColors.red : AppColors.gold),
            minHeight: 3,
          ),
        ),
      ]),
    );
  }

  // ── flash ─────────────────────────────────────────────────────────────────

  Widget _flash() => SizedBox(
      height: 22,
      child: AnimatedBuilder(
        animation: _flashCtrl,
        builder: (_, __) {
          final t = _flashCtrl.value;
          final op = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4);
          return Opacity(
              opacity: op,
              child: Transform.translate(
                  offset: Offset(0, -6 * t),
                  child: Text(_flashText,
                      style: AppText.ui(14,
                          weight: FontWeight.w800,
                          color: _flashColor,
                          letterSpacing: 1.2))));
        },
      ));

  // ── score display ─────────────────────────────────────────────────────────

  Widget _scoreDisplay() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16)),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            AnimatedBuilder(
                animation: _makeBounce,
                builder: (_, __) => Transform.scale(
                      scale: _makeScale.value,
                      child: Column(children: [
                        Text('$_score',
                            style: AppText.display(40, color: AppColors.gold)),
                        Text('SCORE',
                            style: AppText.ui(9,
                                color: AppColors.text3, letterSpacing: 1.4)),
                      ]),
                    )),
            Container(width: 1, height: 36, color: AppColors.borderSub),
            Column(children: [
              Text('$_maxScore',
                  style: AppText.display(40, color: AppColors.text3)),
              Text('MAX',
                  style: AppText.ui(9,
                      color: AppColors.text3, letterSpacing: 1.4)),
            ]),
            Container(width: 1, height: 36, color: AppColors.borderSub),
            Column(children: [
              Text('$_made',
                  style: AppText.display(40, color: AppColors.text1)),
              Text('MADE',
                  style: AppText.ui(9,
                      color: AppColors.text3, letterSpacing: 1.4)),
            ]),
          ]),
        ),
      );

  // ── rack display ──────────────────────────────────────────────────────────

  Widget _rackDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_totalRacks, (r) {
          final isActive = r == _currentRack && !_gameOver;
          return Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.gold.withValues(alpha: 0.08)
                    : AppColors.surface,
                border: Border.all(
                    color: isActive
                        ? AppColors.gold.withValues(alpha: 0.50)
                        : AppColors.border,
                    width: isActive ? 1.5 : 1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: [
                // 5 balls
                ...List.generate(_ballsPerRack, (b) {
                  final isMoney = (r == _moneyRackIndex) || (b == 4);
                  final state = _balls[r][b];
                  final isCurrentBall = isActive && b == _currentBall;
                  return _BallDot(
                      state: state, isMoney: isMoney, isCurrent: isCurrentBall);
                }).reversed,
                const SizedBox(height: 8),
                Text('R${r + 1}',
                    style: AppText.ui(9,
                        color: isActive ? AppColors.gold : AppColors.text3,
                        weight: FontWeight.w700)),
              ]),
            ),
          ));
        }),
      ),
    );
  }

  // ── current rack label ────────────────────────────────────────────────────

  Widget _currentRackLabel() {
    if (_gameOver || _currentRack >= _totalRacks) {
      return Text('Game Over',
          style:
              AppText.ui(16, weight: FontWeight.w700, color: AppColors.text3));
    }
    if (!_gameStarted) {
      return Text('Tap MAKE or MISS to start the clock',
          style: AppText.ui(13, color: AppColors.text3));
    }
    final ballNum = _currentBall + 1;
    final isMoney = (_currentRack == _moneyRackIndex) || (_currentBall == 4);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_rackNames[_currentRack].replaceAll('\n', ' '),
          style:
              AppText.ui(14, weight: FontWeight.w700, color: AppColors.gold)),
      Text(' · Ball $ballNum/5', style: AppText.ui(14, color: AppColors.text2)),
      if (isMoney) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(5)),
          child: Text('MONEY BALL',
              style: AppText.ui(9,
                  weight: FontWeight.w800, color: AppColors.gold)),
        ),
      ],
    ]);
  }

  // ── action buttons ────────────────────────────────────────────────────────

  Widget _actionButtons() {
    final disabled = _gameOver || _currentRack >= _totalRacks;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(
            child: _BigBtn(
                label: 'MISS',
                icon: Icons.close_rounded,
                bg: AppColors.surface,
                fg: AppColors.text2,
                iconColor: AppColors.red,
                border: AppColors.border,
                disabled: disabled,
                onTap: () => _record(false))),
        const SizedBox(width: 14),
        Expanded(
            child: _BigBtn(
                label: 'MAKE',
                icon: Icons.check_rounded,
                bg: AppColors.gold,
                fg: AppColors.bg,
                iconColor: AppColors.bg,
                border: Colors.transparent,
                disabled: disabled,
                onTap: () => _record(true),
                glow: true)),
      ]),
    );
  }
}

// ── Ball dot widget ───────────────────────────────────────────────────────────

class _BallDot extends StatelessWidget {
  final _BallState state;
  final bool isMoney, isCurrent;
  const _BallDot(
      {required this.state, required this.isMoney, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    Color color;
    Widget child;

    switch (state) {
      case _BallState.made:
        color = isMoney ? AppColors.gold : AppColors.green;
        child = Icon(Icons.check_rounded,
            size: 11, color: Colors.black.withValues(alpha: 0.7));
      case _BallState.missed:
        color = AppColors.red.withValues(alpha: 0.35);
        child = const Icon(Icons.close_rounded, size: 10, color: AppColors.red);
      case _BallState.pending:
        color = isCurrent
            ? (isMoney
                ? AppColors.gold.withValues(alpha: 0.30)
                : AppColors.text2.withValues(alpha: 0.25))
            : AppColors.borderSub;
        child = isMoney
            ? Icon(Icons.star_rounded,
                size: 9,
                color: isCurrent
                    ? AppColors.gold
                    : AppColors.text3.withValues(alpha: 0.4))
            : const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
          border: isCurrent && state == _BallState.pending
              ? Border.all(
                  color: isMoney
                      ? AppColors.gold
                      : AppColors.text2.withValues(alpha: 0.5),
                  width: 1.2)
              : null,
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── Result sheet ──────────────────────────────────────────────────────────────

class _ResultSheet extends StatelessWidget {
  final int score, maxScore, made;
  final VoidCallback onRetry, onDone;
  const _ResultSheet(
      {required this.score,
      required this.maxScore,
      required this.made,
      required this.onRetry,
      required this.onDone});

  String get _grade {
    final pct = score / maxScore;
    return PerformanceGuide.gradeFor(pct);
  }

  Color get _gc {
    final p = score / maxScore;
    return PerformanceGuide.colorFor(p);
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)))),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('CONTEST OVER',
                    style: AppText.ui(9,
                        color: AppColors.text3,
                        letterSpacing: 1.8,
                        weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$score',
                      style: AppText.display(52, color: AppColors.gold)),
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Text('/$maxScore pts',
                          style: AppText.ui(16, color: AppColors.text2))),
                ]),
                Text('$made balls made',
                    style: AppText.ui(13, color: AppColors.text3)),
              ])),
          Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: _gc.withValues(alpha: 0.10),
                  border: Border.all(
                      color: _gc.withValues(alpha: 0.38), width: 1.5),
                  borderRadius: BorderRadius.circular(16)),
              child: Center(
                  child: Text(_grade, style: AppText.display(34, color: _gc)))),
        ]),
        const SizedBox(height: 24),
        // NBA comparison
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.text3),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('NBA All-Star record: 27/30 (Craig Hodges, 1991)',
                      style: AppText.ui(11, color: AppColors.text3))),
            ])),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: GestureDetector(
                  onTap: onRetry,
                  child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12)),
                      child: Center(
                          child: Text('Try Again',
                              style: AppText.ui(14,
                                  weight: FontWeight.w600,
                                  color: AppColors.text2)))))),
          const SizedBox(width: 12),
          Expanded(
              flex: 2,
              child: GestureDetector(
                  onTap: onDone,
                  child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(12)),
                      child: Center(
                          child: Text('Done',
                              style: AppText.ui(14,
                                  weight: FontWeight.w700,
                                  color: AppColors.bg)))))),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED MICRO-WIDGETS  (used by multiple game screens)
// ─────────────────────────────────────────────────────────────────────────────

class _SmBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmBtn({required this.icon, required this.onTap});
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
          child: Icon(icon, size: 18, color: AppColors.text2)));
}

class _BigBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color bg, fg, iconColor, border;
  final bool disabled, glow;
  final VoidCallback onTap;
  const _BigBtn(
      {required this.label,
      required this.icon,
      required this.bg,
      required this.fg,
      required this.iconColor,
      required this.border,
      required this.onTap,
      this.disabled = false,
      this.glow = false});
  @override
  State<_BigBtn> createState() => _BigBtnState();
}

class _BigBtnState extends State<_BigBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 100));
  late final Animation<double> _s = Tween(begin: 1.0, end: 0.92)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTapDown: widget.disabled ? null : (_) => _c.forward(),
        onTapUp: widget.disabled
            ? null
            : (_) {
                _c.reverse();
                widget.onTap();
              },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
            animation: _s,
            builder: (_, __) => Transform.scale(
                scale: _s.value,
                child: AnimatedOpacity(
                    opacity: widget.disabled ? 0.35 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                        height: 82,
                        decoration: BoxDecoration(
                            color: widget.bg,
                            borderRadius: BorderRadius.circular(22),
                            border:
                                Border.all(color: widget.border, width: 1.5),
                            boxShadow: widget.glow && !widget.disabled
                                ? [
                                    BoxShadow(
                                        color:
                                            widget.bg.withValues(alpha: 0.28),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5))
                                  ]
                                : null),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(widget.icon,
                                  color: widget.iconColor, size: 28),
                              const SizedBox(height: 5),
                              Text(widget.label,
                                  style: AppText.ui(15,
                                      weight: FontWeight.w800,
                                      color: widget.fg,
                                      letterSpacing: 1.4)),
                            ]))))));
  }
}
