import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/session.dart';
import '../models/shot.dart';
import '../services/session_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  SOLO CHALLENGE SCREEN
//  Handles: beat_the_clock | streak_mode | pressure_fts |
//           hot_spot | around_the_world | mikan_drill
// ═════════════════════════════════════════════════════════════════════════════

class SoloChallengeScreen extends StatefulWidget {
  final String modeId;
  final String title;
  final Color color;

  const SoloChallengeScreen({
    super.key,
    required this.modeId,
    required this.title,
    required this.color,
  });

  @override
  State<SoloChallengeScreen> createState() => _SoloChallengeScreenState();
}

class _SoloChallengeScreenState extends State<SoloChallengeScreen>
    with TickerProviderStateMixin {
  // ── universal shot state ──────────────────────────────────────────────────
  int _made = 0;
  int _attempts = 0;
  final List<bool> _log = [];
  bool _gameOver = false;
  bool _started = false;

  // ── streak mode ───────────────────────────────────────────────────────────
  int _streak = 0;
  int _bestStreak = 0;

  // ── beat the clock ────────────────────────────────────────────────────────
  static const _clockDuration = 60;
  int _secondsLeft = _clockDuration;
  Timer? _timer;

  // ── pressure FTs ──────────────────────────────────────────────────────────
  static const _ftTarget = 10; // consecutive makes needed per level
  int _ftLevel = 1;
  int _ftConsecutive = 0; // current consecutive makes in this level
  static const _ftMaxLevels = 5;

  // ── hot spot ──────────────────────────────────────────────────────────────
  static const _hsSpots = [
    'Left Corner',
    'Left Wing',
    'Top of Arc',
    'Right Wing',
    'Right Corner'
  ];
  static const _hsShotsPerSpot = 10;
  int _hsSpotIndex = 0;
  // [spot][shot] = bool?
  late List<List<bool?>> _hsResults;

  // ── around the world ──────────────────────────────────────────────────────
  static const _atwSpots = [
    'Left Corner',
    'Left Wing',
    'Left Elbow',
    'Free Throw',
    'Right Elbow',
    'Right Wing',
    'Right Corner'
  ];
  int _atwSpot = 0;
  bool _atwStuck = false;
  int _atwConsecutiveMisses = 0;

  // ── mikan drill ───────────────────────────────────────────────────────────
  static const _mikanTarget = 20;
  int _mikanRep = 0; // completed reps
  bool _mikanRight = true; // true=right-hand side

  // ── flash ─────────────────────────────────────────────────────────────────
  String _flash = '';
  Color _flashColor = AppColors.green;
  late final AnimationController _flashCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));

  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420))
    ..forward();

  late final AnimationController _bounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  late final Animation<double> _bounceScale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 0.96), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0), weight: 30),
  ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _hsResults = List.generate(
        _hsSpots.length, (_) => List.filled(_hsShotsPerSpot, null));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flashCtrl.dispose();
    _entry.dispose();
    _bounce.dispose();
    super.dispose();
  }

  // ── timer (beat the clock) ────────────────────────────────────────────────

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _timer?.cancel();
          _endGame('Time\'s up!');
        }
      });
    });
  }

  // ── generic record ────────────────────────────────────────────────────────

  void _record(bool made) {
    if (_gameOver) return;
    HapticFeedback.mediumImpact();

    if (!_started) {
      _started = true;
      if (widget.modeId == 'beat_the_clock') _startClock();
    }

    setState(() {
      switch (widget.modeId) {
        case 'beat_the_clock':
          _recordBtc(made);
        case 'streak_mode':
          _recordStreak(made);
        case 'pressure_fts':
          _recordPressureFT(made);
        case 'hot_spot':
          _recordHotSpot(made);
        case 'around_the_world':
          _recordAtw(made);
        case 'mikan_drill':
          _recordMikan(made);
      }
      _made += made ? 1 : 0;
      _attempts++;
      _log.add(made);
    });

    if (made) _bounce.forward(from: 0);
    _flashCtrl.forward(from: 0);
  }

  // ── mode-specific record logic ────────────────────────────────────────────

  void _recordBtc(bool made) {
    _flash = made ? '+MADE' : 'MISS';
    _flashColor = made ? AppColors.green : AppColors.red;
  }

  void _recordStreak(bool made) {
    if (made) {
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      _flash = '🔥 $_streak IN A ROW';
      _flashColor = AppColors.gold;
    } else {
      _flash = 'STREAK BROKEN · Best: $_bestStreak';
      _flashColor = AppColors.red;
      _streak = 0;
    }
  }

  void _recordPressureFT(bool made) {
    if (made) {
      _ftConsecutive++;
      _flash = '$_ftConsecutive / $_ftTarget';
      _flashColor = AppColors.green;
      if (_ftConsecutive >= _ftTarget) {
        if (_ftLevel >= _ftMaxLevels) {
          _endGame('Challenge Complete! 🏆');
        } else {
          _ftLevel++;
          _ftConsecutive = 0;
          _flash = 'LEVEL $_ftLevel!';
          _flashColor = AppColors.gold;
        }
      }
    } else {
      _flash = 'RESTART LEVEL $_ftLevel';
      _flashColor = AppColors.red;
      _ftConsecutive = 0;
    }
  }

  void _recordHotSpot(bool made) {
    final spot = _hsSpotIndex;
    final shotIdx = _hsResults[spot].indexWhere((e) => e == null);
    if (shotIdx == -1) return;
    _hsResults[spot][shotIdx] = made;
    _flash = made ? '+MADE' : 'MISS';
    _flashColor = made ? AppColors.green : AppColors.red;

    // Move to next spot
    if (shotIdx == _hsShotsPerSpot - 1) {
      if (spot < _hsSpots.length - 1) {
        _hsSpotIndex++;
        _flash = 'NEXT: ${_hsSpots[_hsSpotIndex]}';
        _flashColor = AppColors.blue;
      } else {
        _endGame('Hot Spot Complete!');
      }
    }
  }

  void _recordAtw(bool made) {
    if (made) {
      _atwConsecutiveMisses = 0;
      _atwStuck = false;
      _flash = '✓ ${_atwSpots[_atwSpot]}';
      _flashColor = AppColors.green;
      _atwSpot++;
      if (_atwSpot >= _atwSpots.length) _endGame('Around the World! 🌍');
    } else {
      _atwConsecutiveMisses++;
      if (_atwConsecutiveMisses >= 2) {
        _atwStuck = true;
        _flash = 'STUCK at ${_atwSpots[_atwSpot]}';
        _flashColor = AppColors.red;
      } else {
        _flash = 'Miss 1 · One more = stuck';
        _flashColor = AppColors.gold;
      }
    }
  }

  void _recordMikan(bool made) {
    final side = _mikanRight ? 'RIGHT' : 'LEFT';
    if (made) {
      _mikanRight = !_mikanRight;
      _mikanRep++;
      _flash = made ? '$side ✓ · Rep $_mikanRep/$_mikanTarget' : 'Miss — redo';
      _flashColor = AppColors.green;
      if (_mikanRep >= _mikanTarget) _endGame('Mikan Drill Done! 🏀');
    } else {
      _flash = 'Miss $side — try again';
      _flashColor = AppColors.red;
    }
  }

  // ── undo ─────────────────────────────────────────────────────────────────

  void _undo() {
    if (_log.isEmpty || widget.modeId == 'beat_the_clock') return;
    HapticFeedback.selectionClick();
    setState(() {
      final last = _log.removeLast();
      _attempts--;
      if (last) _made--;
      // Mode-specific undo
      if (widget.modeId == 'streak_mode') {
        _streak = _recomputeStreak();
      }
    });
  }

  int _recomputeStreak() {
    int s = 0;
    for (final b in _log.reversed) {
      if (b) {
        s++;
      } else {
        break;
      }
    }
    return s;
  }

  // ── end game ──────────────────────────────────────────────────────────────

  void _endGame(String message) {
    _timer?.cancel();
    setState(() {
      _gameOver = true;
    });
    _saveSession();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => _SoloResultSheet(
          modeId: widget.modeId,
          title: widget.title,
          color: widget.color,
          made: _made,
          attempts: _attempts,
          log: List.unmodifiable(_log),
          extra: _buildExtra(),
          onRetry: () {
            Navigator.pop(context);
            _restart();
          },
          onDone: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      );
    });
  }

  Future<void> _saveSession() async {
    if (_attempts == 0 && widget.modeId != 'beat_the_clock') return;
    try {
      List<Shot> shots = [];
      for (int i = 0; i < _log.length; i++) {
        shots.add(Shot(
          sessionId: '',
          userId: '',
          orderIdx: i,
          isMake: _log[i],
          isSwish: false,
          createdAt: DateTime.now(),
        ));
      }

      final session = Session(
        userId: '',
        type: 'game',
        mode: widget.modeId == 'hot_spot' || widget.modeId == 'around_the_world'
            ? 'position'
            : 'range',
        selectionId: widget.modeId,
        selectionLabel: widget.title,
        gameModeId: widget.modeId,
        gameData: _buildStats(),
        targetShots: _computeTargetShots(),
        made: _made,
        swishes: 0,
        attempts: _attempts,
        bestStreak: _bestStreak,
        elapsedSeconds: widget.modeId == 'beat_the_clock'
            ? _clockDuration - _secondsLeft
            : 0,
      );

      await SessionService().saveSessionData(session, shots);
    } catch (e) {
      debugPrint('Failed to save solo challenge: $e');
    }
  }

  int _computeTargetShots() {
    switch (widget.modeId) {
      case 'pressure_fts':
        return _ftMaxLevels * _ftTarget;
      case 'hot_spot':
        return _hsSpots.length * _hsShotsPerSpot;
      case 'mikan_drill':
        return _mikanTarget;
      default:
        return 0;
    }
  }

  Map<String, dynamic> _buildStats() {
    switch (widget.modeId) {
      case 'beat_the_clock':
        return {
          'made': _made,
          'attempts': _attempts,
          'secondsUsed': _clockDuration - _secondsLeft,
        };
      case 'streak_mode':
        return {
          'bestStreak': _bestStreak,
          'totalMade': _made,
          'totalAttempts': _attempts,
        };
      case 'pressure_fts':
        return {
          'levelsCleared': _ftLevel - 1,
          'totalLevels': _ftMaxLevels,
          'made': _made,
          'attempts': _attempts,
        };
      case 'hot_spot':
        return {
          'made': _made,
          'attempts': _attempts,
        };
      case 'around_the_world':
        return {
          'spotsCleared': _atwSpot,
          'totalSpots': _atwSpots.length,
          'made': _made,
          'attempts': _attempts,
          'completed': _atwSpot >= _atwSpots.length,
        };
      case 'mikan_drill':
        return {
          'repsDone': _mikanRep,
          'targetReps': _mikanTarget,
          'made': _made,
          'attempts': _attempts,
        };
      default:
        return {};
    }
  }

  Map<String, String> _buildExtra() {
    switch (widget.modeId) {
      case 'beat_the_clock':
        return {'Shots in 60s': '$_attempts', 'Makes': '$_made'};
      case 'streak_mode':
        return {'Best Streak': '$_bestStreak', 'Total shots': '$_attempts'};
      case 'pressure_fts':
        return {
          'Levels cleared': '${_ftLevel - 1}/$_ftMaxLevels',
          'Total shots': '$_attempts'
        };
      case 'hot_spot':
        int best = 0;
        String bestSpot = '—';
        for (int i = 0; i < _hsSpots.length; i++) {
          final m = _hsResults[i].where((e) => e == true).length;
          if (m > best) {
            best = m;
            bestSpot = _hsSpots[i];
          }
        }
        return {'Hot zone': bestSpot, 'Top makes': '$best/10'};
      case 'around_the_world':
        return {
          'Spots cleared': '$_atwSpot/${_atwSpots.length}',
          'Total shots': '$_attempts'
        };
      case 'mikan_drill':
        return {'Reps done': '$_mikanRep/$_mikanTarget', 'Makes': '$_made'};
      default:
        return {};
    }
  }

  void _restart() {
    setState(() {
      _made = 0;
      _attempts = 0;
      _log.clear();
      _gameOver = false;
      _started = false;
      _streak = 0;
      _bestStreak = 0;
      _secondsLeft = _clockDuration;
      _ftLevel = 1;
      _ftConsecutive = 0;
      _hsSpotIndex = 0;
      _hsResults = List.generate(
          _hsSpots.length, (_) => List.filled(_hsShotsPerSpot, null));
      _atwSpot = 0;
      _atwStuck = false;
      _atwConsecutiveMisses = 0;
      _mikanRep = 0;
      _mikanRight = true;
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _entry, curve: Curves.easeOut),
        child: SafeArea(
            child: Column(children: [
          _topBar(),
          const SizedBox(height: 12),
          _flashWidget(),
          const SizedBox(height: 10),
          Expanded(
              child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              _mainDisplay(),
              const SizedBox(height: 20),
              _modeWidget(),
              const SizedBox(height: 16),
            ]),
          )),
          _bottomButtons(),
          const SizedBox(height: 20),
        ])),
      ),
    );
  }

  // ── top bar ───────────────────────────────────────────────────────────────

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        _SmBtn(icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CHALLENGE',
              style: AppText.ui(9,
                  color: AppColors.text3,
                  letterSpacing: 1.8,
                  weight: FontWeight.w700)),
          Text(widget.title, style: AppText.ui(17, weight: FontWeight.w700)),
        ])),
        if (widget.modeId == 'beat_the_clock') _clockChip(),
      ]),
    );
  }

  Widget _clockChip() {
    final urgent = _secondsLeft <= 10;
    final running = _started && !_gameOver;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:
            urgent ? AppColors.red.withValues(alpha: 0.12) : AppColors.surface,
        border: Border.all(
            color: urgent
                ? AppColors.red.withValues(alpha: 0.5)
                : AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(running ? Icons.timer_rounded : Icons.timer_outlined,
            size: 14, color: urgent ? AppColors.red : AppColors.text2),
        const SizedBox(width: 6),
        Text('${_secondsLeft}s',
            style: AppText.display(20,
                color: urgent ? AppColors.red : AppColors.text1)),
      ]),
    );
  }

  // ── flash ─────────────────────────────────────────────────────────────────

  Widget _flashWidget() => SizedBox(
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
                  child: Text(_flash,
                      style: AppText.ui(13,
                          weight: FontWeight.w700,
                          color: _flashColor,
                          letterSpacing: 0.8))));
        },
      ));

  // ── main display (big number) ─────────────────────────────────────────────

  Widget _mainDisplay() {
    final (headline, sub) = _headlineSub();
    return AnimatedBuilder(
        animation: _bounce,
        builder: (_, __) => Transform.scale(
              scale: _bounceScale.value,
              child: Column(children: [
                Text(headline, style: AppText.display(72, color: widget.color)),
                if (sub.isNotEmpty)
                  Text(sub,
                      style: AppText.ui(16,
                          color: AppColors.text2, weight: FontWeight.w500)),
              ]),
            ));
  }

  (String, String) _headlineSub() {
    switch (widget.modeId) {
      case 'beat_the_clock':
        return ('$_made', '$_attempts shots');
      case 'streak_mode':
        return ('$_streak', 'best: $_bestStreak');
      case 'pressure_fts':
        return (
          '$_ftConsecutive/$_ftTarget',
          'Level $_ftLevel of $_ftMaxLevels'
        );
      case 'hot_spot':
        final spotMakes = _hsResults[_hsSpotIndex.clamp(0, _hsSpots.length - 1)]
            .where((e) => e == true)
            .length;
        final spotShots = _hsResults[_hsSpotIndex.clamp(0, _hsSpots.length - 1)]
            .where((e) => e != null)
            .length;
        return (
          '$spotMakes/$spotShots',
          _hsSpotIndex < _hsSpots.length ? _hsSpots[_hsSpotIndex] : 'Done'
        );
      case 'around_the_world':
        return (
          '$_atwSpot/${_atwSpots.length}',
          _atwSpot < _atwSpots.length ? _atwSpots[_atwSpot] : 'Done!'
        );
      case 'mikan_drill':
        return (
          '$_mikanRep/$_mikanTarget',
          _mikanRight ? '← Left side next' : 'Right side next →'
        );
      default:
        return ('$_made', '$_attempts shots');
    }
  }

  // ── mode-specific widget ──────────────────────────────────────────────────

  Widget _modeWidget() {
    switch (widget.modeId) {
      case 'beat_the_clock':
        return _btcWidget();
      case 'streak_mode':
        return _streakWidget();
      case 'pressure_fts':
        return _pressureFtWidget();
      case 'hot_spot':
        return _hotSpotWidget();
      case 'around_the_world':
        return _atwWidget();
      case 'mikan_drill':
        return _mikanWidget();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Beat the Clock widget ─────────────────────────────────────────────────

  Widget _btcWidget() {
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: _secondsLeft / _clockDuration,
                  backgroundColor: AppColors.borderSub,
                  valueColor: AlwaysStoppedAnimation(
                      _secondsLeft <= 10 ? AppColors.red : widget.color),
                  minHeight: 6)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _StatChip('MADE', '$_made', AppColors.green),
            _Divider(),
            _StatChip('MISSED', '${_attempts - _made}', AppColors.red),
            _Divider(),
            _StatChip('TOTAL', '$_attempts', AppColors.text2),
          ]),
          if (!_started)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Tap MAKE or MISS to start the clock',
                    style: AppText.ui(12, color: AppColors.text3))),
        ]));
  }

  // ── Streak widget ─────────────────────────────────────────────────────────

  Widget _streakWidget() {
    final recent = _log.length > 12 ? _log.sublist(_log.length - 12) : _log;
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _StatChip('CURRENT', '$_streak', widget.color),
            _Divider(),
            _StatChip('BEST', '$_bestStreak', AppColors.gold),
            _Divider(),
            _StatChip('TOTAL', '$_attempts', AppColors.text2),
          ]),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: recent
                    .map((m) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: m
                                    ? AppColors.green
                                    : AppColors.red.withValues(alpha: 0.5)))))
                    .toList()),
          ],
        ]));
  }

  // ── Pressure FTs widget ───────────────────────────────────────────────────

  Widget _pressureFtWidget() {
    return Column(children: [
      // Level dots
      Row(
          children: List.generate(_ftMaxLevels, (i) {
        final done = i < _ftLevel - 1;
        final active = i == _ftLevel - 1;
        return Expanded(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 6,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: done
                            ? widget.color
                            : (active
                                ? widget.color.withValues(alpha: 0.35)
                                : AppColors.borderSub)))));
      })),
      const SizedBox(height: 14),
      // FT progress row
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text('Level $_ftLevel — Make $_ftTarget in a row',
                style: AppText.ui(13, color: AppColors.text2)),
            const SizedBox(height: 12),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_ftTarget, (i) {
                  final done = i < _ftConsecutive;
                  return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done ? widget.color : AppColors.borderSub,
                              border: i == _ftConsecutive
                                  ? Border.all(
                                      color:
                                          widget.color.withValues(alpha: 0.5),
                                      width: 1.5)
                                  : null),
                          child: done
                              ? Icon(Icons.check_rounded,
                                  size: 13,
                                  color: Colors.black.withValues(alpha: 0.7))
                              : null));
                })),
          ])),
    ]);
  }

  // ── Hot Spot widget ───────────────────────────────────────────────────────

  Widget _hotSpotWidget() {
    return Column(
        children: _hsSpots.asMap().entries.map((e) {
      final i = e.key;
      final spot = e.value;
      final results = _hsResults[i];
      final makes = results.where((r) => r == true).length;
      final total = results.where((r) => r != null).length;
      final isActive = i == _hsSpotIndex;
      final isDone = total >= _hsShotsPerSpot;
      final pct = total > 0 ? makes / total : 0.0;

      return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                  color: isActive
                      ? widget.color.withValues(alpha: 0.07)
                      : AppColors.surface,
                  border: Border.all(
                      color: isActive
                          ? widget.color.withValues(alpha: 0.45)
                          : AppColors.border,
                      width: isActive ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                // spot index circle
                Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? (pct >= 0.6
                                    ? AppColors.green
                                    : pct >= 0.4
                                        ? AppColors.gold
                                        : AppColors.red)
                                .withValues(alpha: 0.15)
                            : (isActive
                                ? widget.color.withValues(alpha: 0.15)
                                : AppColors.borderSub)),
                    child: Center(
                        child: isDone
                            ? Icon(Icons.check_rounded,
                                size: 14,
                                color: pct >= 0.6
                                    ? AppColors.green
                                    : pct >= 0.4
                                        ? AppColors.gold
                                        : AppColors.red)
                            : Text('${i + 1}',
                                style: AppText.ui(11,
                                    weight: FontWeight.w700,
                                    color: isActive
                                        ? widget.color
                                        : AppColors.text3)))),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(spot,
                          style: AppText.ui(13,
                              weight: FontWeight.w600,
                              color: isActive
                                  ? AppColors.text1
                                  : AppColors.text2)),
                      if (total > 0)
                        ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: AppColors.borderSub,
                                valueColor: AlwaysStoppedAnimation(pct >= 0.6
                                    ? AppColors.green
                                    : pct >= 0.4
                                        ? AppColors.gold
                                        : AppColors.red),
                                minHeight: 3)),
                    ])),
                const SizedBox(width: 10),
                Text(total > 0 ? '$makes/$total' : '—',
                    style: AppText.ui(13,
                        weight: FontWeight.w600,
                        color: isActive ? widget.color : AppColors.text3)),
              ])));
    }).toList());
  }

  // ── Around the World widget ───────────────────────────────────────────────

  Widget _atwWidget() {
    return Column(children: [
      // Arc visualization (text-based court indicator)
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _atwSpots.asMap().entries.map((e) {
                  final i = e.key;
                  final done = i < _atwSpot;
                  final isActive = i == _atwSpot;
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done
                                ? AppColors.green.withValues(alpha: 0.15)
                                : (isActive
                                    ? widget.color.withValues(alpha: 0.15)
                                    : AppColors.borderSub),
                            border: isActive
                                ? Border.all(
                                    color: _atwStuck
                                        ? AppColors.red
                                        : widget.color,
                                    width: 1.5)
                                : null),
                        child: Center(
                            child: done
                                ? const Icon(Icons.check_rounded,
                                    size: 16, color: AppColors.green)
                                : Text('${i + 1}',
                                    style: AppText.ui(12,
                                        weight: FontWeight.w700,
                                        color: isActive
                                            ? widget.color
                                            : AppColors.text3)))),
                    const SizedBox(height: 4),
                    SizedBox(
                        width: 34,
                        child: Text(_atwSpots[i].split(' ').last,
                            style: AppText.ui(8,
                                color:
                                    isActive ? widget.color : AppColors.text3),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis)),
                  ]);
                }).toList()),
            if (_atwStuck)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.red.withValues(alpha: 0.30))),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_rounded,
                                size: 13, color: AppColors.red),
                            const SizedBox(width: 7),
                            Text('Stuck — keep shooting to break free',
                                style: AppText.ui(12, color: AppColors.red)),
                          ]))),
          ])),
    ]);
  }

  // ── Mikan Drill widget ────────────────────────────────────────────────────

  Widget _mikanWidget() {
    return Column(children: [
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            // Side indicator
            Row(children: [
              Expanded(
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 52,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                          color: _mikanRight
                              ? widget.color.withValues(alpha: 0.12)
                              : AppColors.bg,
                          border: Border.all(
                              color:
                                  _mikanRight ? widget.color : AppColors.border,
                              width: _mikanRight ? 1.5 : 1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Center(
                          child: Text('RIGHT',
                              style: AppText.ui(13,
                                  weight: FontWeight.w700,
                                  color: _mikanRight
                                      ? widget.color
                                      : AppColors.text3))))),
              Expanded(
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 52,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                          color: !_mikanRight
                              ? widget.color.withValues(alpha: 0.12)
                              : AppColors.bg,
                          border: Border.all(
                              color: !_mikanRight
                                  ? widget.color
                                  : AppColors.border,
                              width: !_mikanRight ? 1.5 : 1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Center(
                          child: Text('LEFT',
                              style: AppText.ui(13,
                                  weight: FontWeight.w700,
                                  color: !_mikanRight
                                      ? widget.color
                                      : AppColors.text3))))),
            ]),
            const SizedBox(height: 14),
            // Rep progress bar
            ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: _mikanRep / _mikanTarget,
                    backgroundColor: AppColors.borderSub,
                    valueColor: AlwaysStoppedAnimation(widget.color),
                    minHeight: 6)),
            const SizedBox(height: 8),
            Text('$_mikanRep / $_mikanTarget reps completed',
                style: AppText.ui(12, color: AppColors.text3)),
          ])),
    ]);
  }

  // ── bottom buttons ────────────────────────────────────────────────────────

  Widget _bottomButtons() {
    final canUndo = widget.modeId != 'beat_the_clock' && _log.isNotEmpty;
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: _BigBtn(
                    label: 'MISS',
                    icon: Icons.close_rounded,
                    bg: AppColors.surface,
                    fg: AppColors.text2,
                    iconColor: AppColors.red,
                    border: AppColors.border,
                    onTap: () => _record(false))),
            const SizedBox(width: 14),
            Expanded(
                child: _BigBtn(
                    label: 'MAKE',
                    icon: Icons.check_rounded,
                    bg: widget.color,
                    fg: AppColors.bg,
                    iconColor: AppColors.bg,
                    border: Colors.transparent,
                    onTap: () => _record(true),
                    glow: true)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: GestureDetector(
                  onTap: canUndo ? _undo : null,
                  child: AnimatedOpacity(
                      opacity: canUndo ? 1.0 : 0.3,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                              color: AppColors.surface,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.undo_rounded,
                                    size: 15, color: AppColors.text2),
                                const SizedBox(width: 6),
                                Text('Undo',
                                    style:
                                        AppText.ui(12, color: AppColors.text2))
                              ])))),
            ),
            const SizedBox(width: 10),
            GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _endGame('Finished early');
                },
                child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(
                        child: Text('End',
                            style: AppText.ui(12, color: AppColors.text2))))),
          ]),
        ]));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  RESULT SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _SoloResultSheet extends StatelessWidget {
  final String modeId, title;
  final Color color;
  final int made, attempts;
  final List<bool> log;
  final Map<String, String> extra;
  final VoidCallback onRetry, onDone;

  const _SoloResultSheet({
    required this.modeId,
    required this.title,
    required this.color,
    required this.made,
    required this.attempts,
    required this.log,
    required this.extra,
    required this.onRetry,
    required this.onDone,
  });

  String get _pct =>
      attempts > 0 ? '${(made / attempts * 100).round()}%' : '0%';

  String get _grade {
    if (attempts == 0) return '—';
    final p = made / attempts;
    if (p >= 0.85) return 'S';
    if (p >= 0.75) return 'A';
    if (p >= 0.65) return 'B';
    if (p >= 0.50) return 'C';
    return 'D';
  }

  Color get _gc {
    final p = attempts > 0 ? made / attempts : 0.0;
    return p >= 0.75
        ? AppColors.green
        : p >= 0.50
            ? AppColors.gold
            : AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(24)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)))),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('CHALLENGE DONE',
                    style: AppText.ui(9,
                        color: AppColors.text3,
                        letterSpacing: 1.8,
                        weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(title, style: AppText.ui(20, weight: FontWeight.w800)),
              ])),
          Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                  color: _gc.withValues(alpha: 0.10),
                  border: Border.all(
                      color: _gc.withValues(alpha: 0.40), width: 1.5),
                  borderRadius: BorderRadius.circular(15)),
              child: Center(
                  child: Text(_grade, style: AppText.display(32, color: _gc)))),
        ]),
        const SizedBox(height: 20),
        Container(height: 1, color: AppColors.borderSub),
        const SizedBox(height: 16),
        // Stats row
        Row(children: [
          _Tile('MADE', '$made', AppColors.green),
          _Tile('ATTEMPTS', '$attempts', AppColors.text1),
          _Tile('ACC', _pct, _gc),
          ...extra.entries
              .take(1)
              .map((e) => _Tile(e.key.toUpperCase(), e.value, color)),
        ]),
        // Extra stats
        if (extra.length > 1) ...[
          const SizedBox(height: 12),
          Row(
              children: extra.entries
                  .skip(1)
                  .map((e) => Expanded(
                      child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border)),
                          child: Column(children: [
                            Text(e.value,
                                style: AppText.ui(15,
                                    weight: FontWeight.w700, color: color)),
                            Text(e.key,
                                style: AppText.ui(9,
                                    color: AppColors.text3,
                                    letterSpacing: 0.8)),
                          ]))))
                  .toList()),
        ],
        // Shot log
        if (log.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
              spacing: 4,
              runSpacing: 4,
              children: log
                  .take(50)
                  .map((m) => Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: m
                              ? AppColors.green
                              : AppColors.red.withValues(alpha: 0.5))))
                  .toList()),
        ],
        const SizedBox(height: 20),
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
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: color.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ]),
                      child: Center(
                          child: Text('Done',
                              style: AppText.ui(14,
                                  weight: FontWeight.w700,
                                  color: Colors.black)))))),
        ]),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  MICRO WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: AppText.ui(20, weight: FontWeight.w700, color: color)),
        Text(label,
            style: AppText.ui(9, color: AppColors.text3, letterSpacing: 1.0)),
      ]);
}

class _Tile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Tile(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(children: [
        Text(value,
            style: AppText.ui(18, weight: FontWeight.w700, color: color)),
        Text(label,
            style: AppText.ui(9, color: AppColors.text3, letterSpacing: 0.8)),
      ]));
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: AppColors.borderSub);
}

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
          child: Icon(icon, size: 16, color: AppColors.text2)));
}

class _BigBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color bg, fg, iconColor, border;
  final bool glow;
  final VoidCallback onTap;
  const _BigBtn(
      {required this.label,
      required this.icon,
      required this.bg,
      required this.fg,
      required this.iconColor,
      required this.border,
      required this.onTap,
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
  Widget build(BuildContext context) => GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
          animation: _s,
          builder: (_, __) => Transform.scale(
              scale: _s.value,
              child: Container(
                  height: 82,
                  decoration: BoxDecoration(
                      color: widget.bg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: widget.border, width: 1.5),
                      boxShadow: widget.glow
                          ? [
                              BoxShadow(
                                  color: widget.bg.withValues(alpha: 0.28),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5))
                            ]
                          : null),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.icon, color: widget.iconColor, size: 28),
                        const SizedBox(height: 5),
                        Text(widget.label,
                            style: AppText.ui(15,
                                weight: FontWeight.w800,
                                color: widget.fg,
                                letterSpacing: 1.4))
                      ])))));
}
