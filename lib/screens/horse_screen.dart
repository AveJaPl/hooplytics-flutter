import 'package:flutter/material.dart';
import '../main.dart';
import '../utils/haptics.dart';
import '../models/session.dart';
import '../services/session_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  H-O-R-S-E SCREEN
//  Caller makes a shot → Matcher must match it.
//  Matcher misses → gets next letter. Caller misses → no letter, roles swap.
//  First to spell H-O-R-S-E loses.
// ═════════════════════════════════════════════════════════════════════════════

enum _HorsePhase { setup, calling, matching, swapAlert, result }

class HorseScreen extends StatefulWidget {
  const HorseScreen({super.key});
  @override
  State<HorseScreen> createState() => _HorseScreenState();
}

class _HorseScreenState extends State<HorseScreen>
    with TickerProviderStateMixin {
  static const _word = 'HORSE';

  _HorsePhase _phase = _HorsePhase.setup;

  final _p1ctrl = TextEditingController(text: 'Player 1');
  final _p2ctrl = TextEditingController(text: 'Player 2');

  int _p1letters = 0; // number of letters earned
  int _p2letters = 0;

  // 0 = P1 is calling this round, 1 = P2 is calling
  int _callerIndex = 0;

  // Called shot description (user types it)
  final _shotCtrl = TextEditingController();

  // What happened this round

  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380))
    ..forward();
  late final AnimationController _letterPop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
  late final Animation<double> _letterScale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.25), weight: 55),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 45),
  ]).animate(CurvedAnimation(parent: _letterPop, curve: Curves.elasticOut));

  String get _callerName => _callerIndex == 0 ? _p1ctrl.text : _p2ctrl.text;
  String get _matcherName => _callerIndex == 0 ? _p2ctrl.text : _p1ctrl.text;

  int get _matcherLetters => _callerIndex == 0 ? _p2letters : _p1letters;

  bool get _gameOver => _p1letters >= 5 || _p2letters >= 5;
  String get _loser => _p1letters >= 5 ? _p1ctrl.text : _p2ctrl.text;
  String get _winner => _p1letters >= 5 ? _p2ctrl.text : _p1ctrl.text;

  @override
  void dispose() {
    _p1ctrl.dispose();
    _p2ctrl.dispose();
    _shotCtrl.dispose();
    _entry.dispose();
    _letterPop.dispose();
    super.dispose();
  }

  // ── logic ─────────────────────────────────────────────────────────────────

  void _callerShot(bool made) {
    Haptics.mediumImpact();
    if (made) {
      // Caller made it → move to matching phase
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _phase = _HorsePhase.matching;
            _entry.forward(from: 0);
          });
        }
      });
    } else {
      // Caller missed → swap roles, no letter
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _callerIndex = 1 - _callerIndex;
            _shotCtrl.clear();
            _phase = _HorsePhase.swapAlert;
            _entry.forward(from: 0);
          });
        }
      });
    }
  }

  void _matcherShot(bool made) {
    Haptics.mediumImpact();
    if (!made) {
      // Matcher missed → gets a letter
      _letterPop.forward(from: 0);
      setState(() {
        if (_callerIndex == 0) {
          _p2letters++;
        } else {
          _p1letters++;
        }
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        if (_gameOver) {
          setState(() {
            _phase = _HorsePhase.result;
            // Auto-save removed as per standardization request
            _entry.forward(from: 0);
          });
        } else {
          // Same caller goes again (they made, matcher missed)
          setState(() {
            _shotCtrl.clear();
            _phase = _HorsePhase.calling;
            _entry.forward(from: 0);
          });
        }
      });
    } else {
      // Matcher made it → swap caller
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() {
          _callerIndex = 1 - _callerIndex;
          _shotCtrl.clear();
          _phase = _HorsePhase.swapAlert;
          _entry.forward(from: 0);
        });
      });
    }
  }

  Future<void> _saveSession() async {
    try {
      final session = Session(
        userId: '',
        type: 'game',
        mode: 'multiplayer',
        selectionId: 'horse',
        selectionLabel: 'H-O-R-S-E',
        gameModeId: 'horse',
        gameData: {
          'p1Name': _p1ctrl.text,
          'p2Name': _p2ctrl.text,
          'p1Letters': _p1letters,
          'p2Letters': _p2letters,
          'winner': _winner,
          'loser': _loser,
          'totalRounds': 0,
        },
        targetShots: 0,
        made: 0,
        swishes: 0,
        attempts: 0,
        bestStreak: 0,
        elapsedSeconds: 0,
      );

      await SessionService().saveSessionData(session, []);
    } catch (e) {
      debugPrint('Error saving HORSE session: $e');
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _entry, curve: Curves.easeOut),
        child: SafeArea(child: () {
          switch (_phase) {
            case _HorsePhase.setup:
              return _buildSetup();
            case _HorsePhase.calling:
              return _buildCalling();
            case _HorsePhase.matching:
              return _buildMatching();
            case _HorsePhase.swapAlert:
              return _buildSwapAlert();
            case _HorsePhase.result:
              return _buildResult();
          }
        }()),
      ),
    );
  }

  // ── SETUP ─────────────────────────────────────────────────────────────────

  Widget _buildSetup() {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Row(children: [
            _SmBtn(
                icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('H-O-R-S-E',
                  style: AppText.ui(9,
                      color: AppColors.text3,
                      letterSpacing: 1.8,
                      weight: FontWeight.w700)),
              Text('Enter player names',
                  style: AppText.ui(16, weight: FontWeight.w700)),
            ]),
          ])),
      const Spacer(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            // Word preview
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _word
                    .split('')
                    .map((l) => _HorseLetter(
                        letter: l, earned: false, color: AppColors.text3))
                    .toList()),
            const SizedBox(height: 28),
            _NameField(
                label: 'PLAYER 1',
                color: const Color(0xFFAA5EEF),
                controller: _p1ctrl),
            const SizedBox(height: 14),
            _NameField(
                label: 'PLAYER 2',
                color: const Color(0xFFFF7A5C),
                controller: _p2ctrl),
          ])),
      const Spacer(),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: GestureDetector(
            onTap: () {
              Haptics.mediumImpact();
              setState(() {
                _phase = _HorsePhase.calling;
                _entry.forward(from: 0);
              });
            },
            child: Container(
                height: 54,
                decoration: BoxDecoration(
                    color: const Color(0xFFAA5EEF),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFFAA5EEF).withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 5))
                    ]),
                child: Center(
                    child: Text('Start H-O-R-S-E',
                        style: AppText.ui(15,
                            weight: FontWeight.w800, color: Colors.white)))),
          )),
    ]);
  }

  // ── CALLING phase ─────────────────────────────────────────────────────────

  Widget _buildCalling() {
    return Column(children: [
      _horseHeader(),
      const SizedBox(height: 24),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            // Caller indicator
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Color(0xFFAA5EEF))),
                  const SizedBox(width: 10),
                  Text('$_callerName is calling',
                      style: AppText.ui(14, weight: FontWeight.w600)),
                  const Spacer(),
                  Text('Caller', style: AppText.ui(12, color: AppColors.text3)),
                ])),
            const SizedBox(height: 16),
            // Shot description
            Text('CALL YOUR SHOT',
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.6,
                    weight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
                controller: _shotCtrl,
                style: AppText.ui(14),
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'e.g. "Mid-range pull-up from left elbow"',
                  hintStyle: AppText.ui(13, color: AppColors.text3),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(14),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFFAA5EEF), width: 1.5)),
                )),
            const SizedBox(height: 24),
            Text('DID $_callerName MAKE THE SHOT?',
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.3,
                    weight: FontWeight.w700)),
            const SizedBox(height: 12),
          ])),
      const Spacer(),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Row(children: [
            Expanded(
                child: _BigBtn(
                    label: 'MISSED',
                    icon: Icons.close_rounded,
                    bg: AppColors.surface,
                    fg: AppColors.text2,
                    iconColor: AppColors.red,
                    border: AppColors.border,
                    onTap: () => _callerShot(false))),
            const SizedBox(width: 14),
            Expanded(
                child: _BigBtn(
                    label: 'MADE IT',
                    icon: Icons.check_rounded,
                    bg: const Color(0xFFAA5EEF),
                    fg: Colors.white,
                    iconColor: Colors.white,
                    border: Colors.transparent,
                    onTap: () => _callerShot(true),
                    glow: true)),
          ])),
    ]);
  }

  // ── MATCHING phase ────────────────────────────────────────────────────────

  Widget _buildMatching() {
    final shotDesc = _shotCtrl.text.trim().isEmpty
        ? 'the called shot'
        : '"${_shotCtrl.text.trim()}"';

    return Column(children: [
      _horseHeader(),
      const Spacer(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            // Matcher challenge
            Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFFFF7A5C).withValues(alpha: 0.15),
                      const Color(0xFFFF7A5C).withValues(alpha: 0.04)
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: Border.all(
                        color: const Color(0xFFFF7A5C).withValues(alpha: 0.30)),
                    borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              const Color(0xFFFF7A5C).withValues(alpha: 0.15)),
                      child: const Icon(Icons.sports_basketball_rounded,
                          color: Color(0xFFFF7A5C), size: 24)),
                  const SizedBox(height: 14),
                  Text('$_matcherName must match',
                      style: AppText.ui(12, color: AppColors.text2)),
                  const SizedBox(height: 6),
                  Text(shotDesc,
                      style: AppText.ui(16, weight: FontWeight.w700),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('Miss this = get a letter',
                      style: AppText.ui(12, color: AppColors.text3)),
                  const SizedBox(height: 14),
                  // Matcher's current letters
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final earned = i < _matcherLetters;
                        return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Text(_word[i],
                                style: AppText.display(22,
                                    color: earned
                                        ? const Color(0xFFFF7A5C)
                                        : AppColors.text3
                                            .withValues(alpha: 0.25))));
                      })),
                ])),
            const SizedBox(height: 28),
            Text('DID $_matcherName MATCH IT?',
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.3,
                    weight: FontWeight.w700)),
            const SizedBox(height: 12),
          ])),
      const Spacer(),
      // Letter pop animation
      AnimatedBuilder(
          animation: _letterPop,
          builder: (_, __) {
            if (_letterPop.value == 0) return const SizedBox.shrink();
            final earned = _callerIndex == 0 ? _p2letters : _p1letters;
            if (earned == 0) return const SizedBox.shrink();
            return Transform.scale(
                scale: _letterScale.value,
                child: Text(_word[earned - 1],
                    style:
                        AppText.display(48, color: const Color(0xFFFF7A5C))));
          }),
      const SizedBox(height: 12),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Row(children: [
            Expanded(
                child: _BigBtn(
                    label: 'MISSED',
                    icon: Icons.close_rounded,
                    bg: AppColors.surface,
                    fg: AppColors.text2,
                    iconColor: AppColors.red,
                    border: AppColors.border,
                    onTap: () => _matcherShot(false))),
            const SizedBox(width: 14),
            Expanded(
                child: _BigBtn(
                    label: 'MATCHED',
                    icon: Icons.check_rounded,
                    bg: AppColors.green,
                    fg: Colors.black,
                    iconColor: Colors.black,
                    border: Colors.transparent,
                    onTap: () => _matcherShot(true),
                    glow: true)),
          ])),
    ]);
  }

  // ── SWAP ALERT phase ──────────────────────────────────────────────────────

  Widget _buildSwapAlert() {
    return Column(children: [
      const Spacer(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: [
            const Icon(Icons.swap_horiz_rounded,
                size: 56, color: AppColors.text3),
            const SizedBox(height: 18),
            Text('Switch!', style: AppText.display(36, color: AppColors.text1)),
            const SizedBox(height: 10),
            Text('$_callerName is now the caller',
                style: AppText.ui(16, color: AppColors.text2),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            _horseScore(),
          ])),
      const Spacer(),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: GestureDetector(
              onTap: () {
                Haptics.mediumImpact();
                setState(() {
                  _phase = _HorsePhase.calling;
                  _entry.forward(from: 0);
                });
              },
              child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(
                      child: Text('Continue →',
                          style: AppText.ui(15,
                              weight: FontWeight.w700,
                              color: AppColors.text1)))))),
    ]);
  }

  // ── RESULT ────────────────────────────────────────────────────────────────

  Widget _buildResult() {
    return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Column(children: [
          const Text('🎯', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text(_winner,
              style: AppText.ui(28,
                  weight: FontWeight.w800, color: const Color(0xFFAA5EEF))),
          Text('wins!', style: AppText.ui(18, color: AppColors.text2)),
          const SizedBox(height: 8),
          Text('$_loser spells H-O-R-S-E',
              style: AppText.ui(14, color: AppColors.text3)),
          const SizedBox(height: 28),
          _horseScore(large: true),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
                child: GestureDetector(
                    onTap: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
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
            const SizedBox(width: 12),
            Expanded(
                child: GestureDetector(
                    onTap: () async {
                      await _saveSession();
                      if (mounted) {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      }
                    },
                    child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                            color: const Color(0xFFAA5EEF),
                            borderRadius: BorderRadius.circular(14)),
                        child: Center(
                            child: Text('Save',
                                style: AppText.ui(14,
                                    weight: FontWeight.w700,
                                    color: Colors.white)))))),
          ]),
        ]));
  }

  // ── shared header ─────────────────────────────────────────────────────────

  Widget _horseHeader() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(children: [
          _SmBtn(
              icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
          const SizedBox(width: 14),
          Expanded(child: _horseScore()),
        ]));
  }

  Widget _horseScore({bool large = false}) {
    final size = large ? 30.0 : 22.0;
    return Row(
        mainAxisAlignment:
            large ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!large)
              Text(_p1ctrl.text,
                  style: AppText.ui(10, color: AppColors.text3),
                  overflow: TextOverflow.ellipsis),
            Row(
                children: List.generate(
                    5,
                    (i) => Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Text(_word[i],
                            style: AppText.display(size,
                                color: i < _p1letters
                                    ? const Color(0xFFAA5EEF)
                                    : AppColors.text3
                                        .withValues(alpha: 0.22)))))),
          ]),
          Padding(
              padding: EdgeInsets.symmetric(horizontal: large ? 20 : 12),
              child: Text('vs', style: AppText.ui(12, color: AppColors.text3))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (!large)
              Text(_p2ctrl.text,
                  style: AppText.ui(10, color: AppColors.text3),
                  overflow: TextOverflow.ellipsis),
            Row(
                children: List.generate(
                    5,
                    (i) => Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Text(_word[i],
                            style: AppText.display(size,
                                color: i < _p2letters
                                    ? const Color(0xFFFF7A5C)
                                    : AppColors.text3
                                        .withValues(alpha: 0.22)))))),
          ]),
        ]);
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _HorseLetter extends StatelessWidget {
  final String letter;
  final bool earned;
  final Color color;
  const _HorseLetter(
      {required this.letter, required this.earned, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(letter,
          style: AppText.display(32,
              color:
                  earned ? color : AppColors.text3.withValues(alpha: 0.20))));
}

class _NameField extends StatelessWidget {
  final String label;
  final Color color;
  final TextEditingController controller;
  const _NameField(
      {required this.label, required this.color, required this.controller});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: AppText.ui(9,
                color: AppColors.text3,
                letterSpacing: 1.6,
                weight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
            controller: controller,
            style: AppText.ui(16, weight: FontWeight.w600),
            decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: color, width: 1.5)))),
      ]);
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
