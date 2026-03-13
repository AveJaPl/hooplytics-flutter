import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../utils/haptics.dart';
import '../models/session.dart';
import '../models/shot.dart';
import '../services/session_service.dart';
import '../utils/performance.dart';
// ═════════════════════════════════════════════════════════════════════════════
//  DUEL SCREEN  –  2 players, 10 shots each, same spot, best % wins
// ═════════════════════════════════════════════════════════════════════════════

enum _DuelPhase { setup, p1playing, handoff, p2playing, result }

class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});
  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> with TickerProviderStateMixin {
  static const _shotsPerPlayer = 10;

  _DuelPhase _phase = _DuelPhase.setup;

  // names
  final _p1ctrl = TextEditingController(text: 'Player 1');
  final _p2ctrl = TextEditingController(text: 'Player 2');

  // scores
  int _p1made = 0, _p1attempts = 0;
  int _p2made = 0, _p2attempts = 0;
  final List<bool> _p1log = [], _p2log = [];

  // active player aliases
  int get _curMade => _phase == _DuelPhase.p1playing ? _p1made : _p2made;
  int get _curAttempts =>
      _phase == _DuelPhase.p1playing ? _p1attempts : _p2attempts;
  List<bool> get _curLog => _phase == _DuelPhase.p1playing ? _p1log : _p2log;
  String get _curName =>
      _phase == _DuelPhase.p1playing ? _p1ctrl.text : _p2ctrl.text;

  Color get _curColor =>
      _phase == _DuelPhase.p1playing ? AppColors.gold : AppColors.blue;

  // flash
  String _flash = '';
  Color _flashColor = AppColors.green;
  late final AnimationController _flashCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));

  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420))
    ..forward();

  late final AnimationController _scaleBounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.16), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.16, end: 0.96), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0), weight: 30),
  ]).animate(CurvedAnimation(parent: _scaleBounce, curve: Curves.easeOut));

  @override
  void dispose() {
    _p1ctrl.dispose();
    _p2ctrl.dispose();
    _flashCtrl.dispose();
    _entry.dispose();
    _scaleBounce.dispose();
    super.dispose();
  }

  // ── actions ───────────────────────────────────────────────────────────────

  void _record(bool made) {
    if (_curAttempts >= _shotsPerPlayer) return;
    Haptics.mediumImpact();

    setState(() {
      if (_phase == _DuelPhase.p1playing) {
        if (made) _p1made++;
        _p1attempts++;
        _p1log.add(made);
      } else {
        if (made) _p2made++;
        _p2attempts++;
        _p2log.add(made);
      }
      _flash = made ? '+MADE' : 'MISS';
      _flashColor = made ? AppColors.green : AppColors.red;
    });

    _flashCtrl.forward(from: 0);
    if (made) _scaleBounce.forward(from: 0);

    // Auto-advance when shots used up
    final attempts = _phase == _DuelPhase.p1playing ? _p1attempts : _p2attempts;
    if (attempts >= _shotsPerPlayer) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _phase = _phase == _DuelPhase.p1playing
              ? _DuelPhase.handoff
              : _DuelPhase.result;
          if (_phase == _DuelPhase.result) {
            _saveSession();
          }
        });
        _entry.forward(from: 0);
      });
    }
  }

  void _undo() {
    if (_curLog.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      final last = _curLog.removeLast();
      if (_phase == _DuelPhase.p1playing) {
        _p1attempts--;
        if (last) _p1made--;
      } else {
        _p2attempts--;
        if (last) _p2made--;
      }
    });
  }

  Future<void> _saveSession() async {
    if (_p1attempts == 0 && _p2attempts == 0) return;
    try {
      List<Shot> shots = [];
      for (int i = 0; i < _p1log.length; i++) {
        shots.add(Shot(
          sessionId: '',
          userId: '',
          orderIdx: i,
          isMake: _p1log[i],
          isSwish: false,
          createdAt: DateTime.now(),
        ));
      }
      for (int i = 0; i < _p2log.length; i++) {
        shots.add(Shot(
          sessionId: '',
          userId: '',
          orderIdx: _p1log.length + i,
          isMake: _p2log[i],
          isSwish: false,
          createdAt: DateTime.now(),
        ));
      }

      final p1pct = _p1attempts > 0 ? _p1made / _p1attempts : 0.0;
      final p2pct = _p2attempts > 0 ? _p2made / _p2attempts : 0.0;
      final p1wins = p1pct > p2pct;
      final tie = p1pct == p2pct;
      final winner = tie ? 'TIE' : (p1wins ? _p1ctrl.text : _p2ctrl.text);

      final session = Session(
        userId: '',
        type: 'game',
        mode: 'multiplayer',
        selectionId: 'duel',
        selectionLabel: 'Duel',
        gameModeId: 'duel',
        gameData: {
          'p1Name': _p1ctrl.text,
          'p2Name': _p2ctrl.text,
          'p1Made': _p1made,
          'p1Attempts': _p1attempts,
          'p2Made': _p2made,
          'p2Attempts': _p2attempts,
          'p1Log': _p1log,
          'p2Log': _p2log,
          'winner': winner,
        },
        targetShots: _shotsPerPlayer * 2,
        made: _p1made + _p2made,
        swishes: 0,
        attempts: _p1attempts + _p2attempts,
        bestStreak: 0,
        elapsedSeconds: 0,
      );

      await SessionService().saveSessionData(session, shots);
    } catch (e) {
      debugPrint('Error saving Duel session: $e');
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
            case _DuelPhase.setup:
              return _buildSetup();
            case _DuelPhase.p1playing:
            case _DuelPhase.p2playing:
              return _buildPlaying();
            case _DuelPhase.handoff:
              return _buildHandoff();
            case _DuelPhase.result:
              return _buildResult();
          }
        }()),
      ),
    );
  }

  // ── SETUP phase ───────────────────────────────────────────────────────────

  Widget _buildSetup() {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Row(children: [
            _SmBtn(
                icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DUEL',
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
            _PlayerNameField(
                label: 'PLAYER 1', color: AppColors.gold, controller: _p1ctrl),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 40, height: 1, color: AppColors.border),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('VS',
                      style: AppText.display(18, color: AppColors.text3))),
              Container(width: 40, height: 1, color: AppColors.border),
            ]),
            const SizedBox(height: 16),
            _PlayerNameField(
                label: 'PLAYER 2', color: AppColors.blue, controller: _p2ctrl),
            const SizedBox(height: 32),
            // Shot count picker
            Text('SHOTS EACH',
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.6,
                    weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(
                    children: [
                  const _ShotsChip(10, true),
                  const _ShotsChip(25, false)
                ].map((w) => w).toList())),
          ])),
      const Spacer(),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: GestureDetector(
            onTap: () {
              Haptics.mediumImpact();
              setState(() {
                _phase = _DuelPhase.p1playing;
                _entry.forward(from: 0);
              });
            },
            child: Container(
                height: 54,
                decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 5))
                    ]),
                child: Center(
                    child: Text('Start Duel',
                        style: AppText.ui(15,
                            weight: FontWeight.w800, color: AppColors.bg)))),
          )),
    ]);
  }

  // ── PLAYING phase ─────────────────────────────────────────────────────────

  Widget _buildPlaying() {
    final pct = _curAttempts == 0 ? 0.0 : _curMade / _curAttempts;
    final pctStr = _curAttempts == 0 ? '—' : '${(pct * 100).round()}%';
    final pctColor =
        _curAttempts == 0 ? AppColors.text3 : PerformanceGuide.colorFor(pct);
    final shotsLeft = _shotsPerPlayer - _curAttempts;

    return Column(children: [
      // Top bar
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Row(children: [
            _SmBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _phase = _DuelPhase.setup;
                    _p1made = 0;
                    _p1attempts = 0;
                    _p1log.clear();
                    _p2made = 0;
                    _p2attempts = 0;
                    _p2log.clear();
                    _entry.forward(from: 0);
                  });
                }),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      'DUEL · ${_phase == _DuelPhase.p1playing ? "ROUND 1" : "ROUND 2"}',
                      style: AppText.ui(9,
                          color: AppColors.text3,
                          letterSpacing: 1.8,
                          weight: FontWeight.w700)),
                  Text(_curName,
                      style: AppText.ui(18, weight: FontWeight.w800)),
                ])),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: _curColor.withValues(alpha: 0.10),
                    border:
                        Border.all(color: _curColor.withValues(alpha: 0.40)),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('$shotsLeft left',
                    style: AppText.ui(13,
                        weight: FontWeight.w700, color: _curColor))),
          ])),
      const SizedBox(height: 20),
      // Shot dots progress
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
              children: List.generate(_shotsPerPlayer, (i) {
            final filled = i < _curAttempts;
            final wasMade = filled && i < _curLog.length ? _curLog[i] : false;
            final isCurrent = i == _curAttempts;
            return Expanded(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 8,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: !filled
                                ? (isCurrent
                                    ? _curColor.withValues(alpha: 0.25)
                                    : AppColors.borderSub)
                                : (wasMade
                                    ? AppColors.green
                                    : AppColors.red.withValues(alpha: 0.5))))));
          }))),
      const SizedBox(height: 28),
      // Flash
      SizedBox(
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
                            style: AppText.ui(14,
                                weight: FontWeight.w800,
                                color: _flashColor,
                                letterSpacing: 1.2))));
              })),
      const SizedBox(height: 16),
      // Big accuracy
      AnimatedBuilder(
          animation: _scaleBounce,
          builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Column(children: [
                Text(pctStr, style: AppText.display(72, color: pctColor)),
                Text('$_curMade / $_curAttempts',
                    style: AppText.ui(18,
                        color: AppColors.text2, weight: FontWeight.w600)),
              ]))),
      const Spacer(),
      // Undo row
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
            onTap: _undo,
            child: AnimatedOpacity(
                opacity: _curLog.isEmpty ? 0.3 : 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.undo_rounded,
                              size: 16, color: AppColors.text2),
                          const SizedBox(width: 7),
                          Text('Undo',
                              style: AppText.ui(13, color: AppColors.text2))
                        ])))),
      ),
      const SizedBox(height: 14),
      // Action buttons
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Row(children: [
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
                    bg: _curColor,
                    fg: AppColors.bg,
                    iconColor: AppColors.bg,
                    border: Colors.transparent,
                    onTap: () => _record(true),
                    glow: true)),
          ])),
    ]);
  }

  // ── HANDOFF phase ─────────────────────────────────────────────────────────

  Widget _buildHandoff() {
    final p1pct = _p1attempts > 0 ? (_p1made / _p1attempts * 100).round() : 0;

    return Column(children: [
      const Spacer(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  Text('${_p1ctrl.text} FINISHED',
                      style: AppText.ui(10,
                          color: AppColors.text3,
                          letterSpacing: 1.6,
                          weight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Text('$p1pct%',
                      style: AppText.display(64, color: AppColors.gold)),
                  Text('$_p1made / $_p1attempts made',
                      style: AppText.ui(15, color: AppColors.text2)),
                  const SizedBox(height: 16),
                  // Shot log
                  Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _p1log
                          .map((m) => Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: m
                                      ? AppColors.green
                                      : AppColors.red.withValues(alpha: 0.5))))
                          .toList()),
                ])),
            const SizedBox(height: 28),
            Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.06),
                    border: Border.all(
                        color: AppColors.blue.withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.person_rounded,
                      color: AppColors.blue, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Pass device to',
                            style: AppText.ui(12, color: AppColors.text2)),
                        Text(_p2ctrl.text,
                            style: AppText.ui(17,
                                weight: FontWeight.w800,
                                color: AppColors.blue)),
                      ])),
                ])),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () {
                Haptics.mediumImpact();
                setState(() {
                  _phase = _DuelPhase.p2playing;
                  _entry.forward(from: 0);
                });
              },
              child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.blue.withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 5))
                      ]),
                  child: Center(
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Text("I'm ready",
                            style: AppText.ui(15,
                                weight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 18, color: Colors.white),
                      ]))),
            ),
          ])),
      const Spacer(),
    ]);
  }

  // ── RESULT phase ──────────────────────────────────────────────────────────

  Widget _buildResult() {
    final p1pct = _p1attempts > 0 ? _p1made / _p1attempts : 0.0;
    final p2pct = _p2attempts > 0 ? _p2made / _p2attempts : 0.0;
    final p1wins = p1pct > p2pct;
    final tie = p1pct == p2pct;
    final winner = tie ? 'TIE!' : (p1wins ? _p1ctrl.text : _p2ctrl.text);
    final winColor =
        tie ? AppColors.gold : (p1wins ? AppColors.gold : AppColors.blue);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(children: [
        // Winner banner
        Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  winColor.withValues(alpha: 0.22),
                  winColor.withValues(alpha: 0.06)
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: Border.all(color: winColor.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(22)),
            child: Column(children: [
              Text(tie ? '🤝' : '🏆', style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 10),
              Text(tie ? 'IT\'S A TIE' : 'WINNER',
                  style: AppText.ui(11,
                      color: winColor,
                      letterSpacing: 1.6,
                      weight: FontWeight.w700)),
              Text(winner,
                  style:
                      AppText.ui(28, weight: FontWeight.w800, color: winColor)),
            ])),
        const SizedBox(height: 20),
        // Side-by-side comparison
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _PlayerResultCard(
                  name: _p1ctrl.text,
                  made: _p1made,
                  attempts: _p1attempts,
                  log: _p1log,
                  color: AppColors.gold,
                  winner: !tie && p1wins)),
          const SizedBox(width: 12),
          Expanded(
              child: _PlayerResultCard(
                  name: _p2ctrl.text,
                  made: _p2made,
                  attempts: _p2attempts,
                  log: _p2log,
                  color: AppColors.blue,
                  winner: !tie && !p1wins)),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
              child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _p1made = 0;
                      _p1attempts = 0;
                      _p1log.clear();
                      _p2made = 0;
                      _p2attempts = 0;
                      _p2log.clear();
                      _phase = _DuelPhase.setup;
                      _entry.forward(from: 0);
                    });
                  },
                  child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12)),
                      child: Center(
                          child: Text('Rematch',
                              style: AppText.ui(14,
                                  weight: FontWeight.w600,
                                  color: AppColors.text2)))))),
          const SizedBox(width: 12),
          Expanded(
              flex: 2,
              child: GestureDetector(
                  onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
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

// ── Player result card ────────────────────────────────────────────────────────

class _PlayerResultCard extends StatelessWidget {
  final String name;
  final int made, attempts;
  final List<bool> log;
  final Color color;
  final bool winner;
  const _PlayerResultCard(
      {required this.name,
      required this.made,
      required this.attempts,
      required this.log,
      required this.color,
      required this.winner});

  @override
  Widget build(BuildContext context) {
    final pct = attempts > 0 ? (made / attempts * 100).round() : 0;
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: winner ? color.withValues(alpha: 0.07) : AppColors.surface,
            border: Border.all(
                color:
                    winner ? color.withValues(alpha: 0.40) : AppColors.border,
                width: winner ? 1.5 : 1),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (winner)
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('WINNER',
                    style: AppText.ui(9,
                        color: color,
                        letterSpacing: 1.3,
                        weight: FontWeight.w700))),
          Text(name,
              style: AppText.ui(13, weight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text('$pct%', style: AppText.display(36, color: color)),
          Text('$made/$attempts',
              style: AppText.ui(11, color: AppColors.text3)),
          const SizedBox(height: 10),
          Wrap(
              spacing: 4,
              runSpacing: 4,
              children: log
                  .map((m) => Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: m
                              ? AppColors.green
                              : AppColors.red.withValues(alpha: 0.5))))
                  .toList()),
        ]));
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _PlayerNameField extends StatelessWidget {
  final String label;
  final Color color;
  final TextEditingController controller;
  const _PlayerNameField(
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
                  borderSide: BorderSide(color: color, width: 1.5)),
            )),
      ]);
}

class _ShotsChip extends StatelessWidget {
  final int shots;
  final bool active;
  const _ShotsChip(this.shots, this.active);
  @override
  Widget build(BuildContext context) => Expanded(
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: active ? AppColors.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(7)),
          child: Center(
              child: Text('$shots',
                  style: AppText.ui(13,
                      weight: FontWeight.w600,
                      color: active ? AppColors.bg : AppColors.text3)))));
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
