import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../main.dart';
import '../utils/haptics.dart';
import '../models/session.dart';
import '../models/shot.dart';
import '../services/session_service.dart';
import '../widgets/tracking_body.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  DUEL SCREEN  –  2 players, same spot, best % wins
//  Uses TrackingBody (same UI as live sessions) for playing phases.
//  After P1 finishes: shows handoff sheet with P1 score.
//  After P2 finishes: shows result sheet with winner + save/discard.
// ═════════════════════════════════════════════════════════════════════════════

enum _DuelPhase { setup, p1playing, p2playing }

class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});
  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen>
    with SingleTickerProviderStateMixin {
  int _shotsPerPlayer = 10;

  _DuelPhase _phase = _DuelPhase.setup;

  final _p1ctrl = TextEditingController(text: 'Player 1');
  final _p2ctrl = TextEditingController(text: 'Player 2');

  TrackingResult? _p1Result;

  late final AnimationController _setupFade = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420))
    ..forward();

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['display_name'] as String?;
    if (name != null && name.isNotEmpty) {
      _p1ctrl.text = name;
    }
  }

  @override
  void dispose() {
    _p1ctrl.dispose();
    _p2ctrl.dispose();
    _setupFade.dispose();
    super.dispose();
  }

  // ── Callbacks ──────────────────────────────────────────────────────────────

  void _onP1Finished(TrackingResult result) {
    if (!mounted) return;
    _p1Result = result;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _DuelHandoffSheet(
        p1Name: _p1ctrl.text,
        p2Name: _p2ctrl.text,
        result: result,
        onReady: () {
          Navigator.of(context).pop();
          setState(() => _phase = _DuelPhase.p2playing);
        },
      ),
    );
  }

  void _onP2Finished(TrackingResult result) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _DuelResultSheet(
        p1Name: _p1ctrl.text,
        p2Name: _p2ctrl.text,
        p1Result: _p1Result!,
        p2Result: result,
        onSave: () => _saveSession(_p1Result!, result),
        onDone: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    );
  }

  Future<void> _saveSession(TrackingResult p1r, TrackingResult p2r) async {
    try {
      // int log: 0=miss, 1=make, 2=swish (backward-compatible with history detail)
      final p1log = p1r.log
          .map((r) => r == ShotResult.swish ? 2 : r == ShotResult.make ? 1 : 0)
          .toList();
      final p2log = p2r.log
          .map((r) => r == ShotResult.swish ? 2 : r == ShotResult.make ? 1 : 0)
          .toList();

      final p1pct = p1r.attempts > 0 ? p1r.made / p1r.attempts : 0.0;
      final p2pct = p2r.attempts > 0 ? p2r.made / p2r.attempts : 0.0;
      final p1wins = p1pct > p2pct;
      final tie = p1pct == p2pct;
      final winner = tie ? 'TIE' : (p1wins ? _p1ctrl.text : _p2ctrl.text);

      final List<Shot> shots = [];
      for (int i = 0; i < p1r.log.length; i++) {
        final r = p1r.log[i];
        shots.add(Shot(
          sessionId: '',
          userId: '',
          orderIdx: i,
          isMake: r != ShotResult.miss,
          isSwish: r == ShotResult.swish,
          createdAt: DateTime.now(),
        ));
      }
      for (int i = 0; i < p2r.log.length; i++) {
        final r = p2r.log[i];
        shots.add(Shot(
          sessionId: '',
          userId: '',
          orderIdx: p1r.log.length + i,
          isMake: r != ShotResult.miss,
          isSwish: r == ShotResult.swish,
          createdAt: DateTime.now(),
        ));
      }

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
          'p1Made': p1r.made,
          'p1Attempts': p1r.attempts,
          'p1Swishes': p1r.swishes,
          'p2Made': p2r.made,
          'p2Attempts': p2r.attempts,
          'p2Swishes': p2r.swishes,
          'p1Log': p1log,
          'p2Log': p2log,
          'winner': winner,
        },
        targetShots: _shotsPerPlayer * 2,
        made: p1r.made + p2r.made,
        swishes: p1r.swishes + p2r.swishes,
        attempts: p1r.attempts + p2r.attempts,
        bestStreak: 0,
        elapsedSeconds: (p1r.elapsed + p2r.elapsed).inSeconds,
      );

      await SessionService().saveSessionData(session, shots);
    } catch (e) {
      debugPrint('Error saving Duel session: $e');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: switch (_phase) {
          _DuelPhase.setup => FadeTransition(
              opacity:
                  CurvedAnimation(parent: _setupFade, curve: Curves.easeOut),
              child: _buildSetup(),
            ),
          _DuelPhase.p1playing => TrackingBody(
              key: const ValueKey('duel_p1'),
              title: _p1ctrl.text,
              subtitle: 'DUEL · ROUND 1',
              accentColor: AppColors.gold,
              voiceEnabled: true,
              swishEnabled: true,
              autoFinishAt: _shotsPerPlayer,
              onBack: () => setState(() => _phase = _DuelPhase.setup),
              onFinished: _onP1Finished,
            ),
          _DuelPhase.p2playing => TrackingBody(
              key: const ValueKey('duel_p2'),
              title: _p2ctrl.text,
              subtitle: 'DUEL · ROUND 2',
              accentColor: AppColors.blue,
              voiceEnabled: true,
              swishEnabled: true,
              autoFinishAt: _shotsPerPlayer,
              onBack: () => setState(() {
                    _phase = _DuelPhase.setup;
                    _p1Result = null;
                  }),
              onFinished: _onP2Finished,
            ),
        },
      ),
    );
  }

  // ── Setup phase ────────────────────────────────────────────────────────────

  Widget _buildSetup() {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Row(children: [
            _SmBtn(
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(context)),
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
                label: 'PLAYER 1',
                color: AppColors.gold,
                controller: _p1ctrl),
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
                label: 'PLAYER 2',
                color: AppColors.blue,
                controller: _p2ctrl),
            const SizedBox(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('SHOTS EACH',
                  style: AppText.ui(9,
                      color: AppColors.text3,
                      letterSpacing: 1.6,
                      weight: FontWeight.w700)),
              Text('$_shotsPerPlayer',
                  style: AppText.display(22, color: AppColors.blue)),
            ]),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.blue,
                inactiveTrackColor: AppColors.border,
                thumbColor: AppColors.blue,
                overlayColor: AppColors.blue.withValues(alpha: 0.15),
                trackHeight: 4,
              ),
              child: Slider(
                value: _shotsPerPlayer.toDouble(),
                min: 5,
                max: 100,
                divisions: 19,
                onChanged: (v) => setState(() => _shotsPerPlayer = v.round()),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('5', style: AppText.ui(10, color: AppColors.text3)),
              Text('100', style: AppText.ui(10, color: AppColors.text3)),
            ]),
          ])),
      const Spacer(),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: GestureDetector(
            onTap: () {
              Haptics.mediumImpact();
              setState(() {
                _phase = _DuelPhase.p1playing;
                _p1Result = null;
                _setupFade.forward(from: 0);
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
                    child: Text('Start Duel',
                        style: AppText.ui(15,
                            weight: FontWeight.w800,
                            color: Colors.white)))),
          )),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DUEL HANDOFF SHEET  –  shown after P1 finishes, before P2 starts
// ═════════════════════════════════════════════════════════════════════════════

class _DuelHandoffSheet extends StatelessWidget {
  final String p1Name, p2Name;
  final TrackingResult result;
  final VoidCallback onReady;

  const _DuelHandoffSheet({
    required this.p1Name,
    required this.p2Name,
    required this.result,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    final pct = result.attempts > 0
        ? (result.made / result.attempts * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          // P1 result card — full width, blue accent
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.08),
                border: Border.all(color: AppColors.blue.withValues(alpha: 0.30)),
                borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              Text('${p1Name.toUpperCase()} DONE',
                  style: AppText.ui(10,
                      color: AppColors.blue.withValues(alpha: 0.70),
                      letterSpacing: 1.6,
                      weight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('$pct%',
                  style: AppText.display(64, color: AppColors.blue)),
              const SizedBox(height: 2),
              Text('${result.made} / ${result.attempts} made',
                  style: AppText.ui(15, color: AppColors.text2)),
              if (result.swishes > 0) ...[
                const SizedBox(height: 4),
                Text('${result.swishes} swishes ✨',
                    style: AppText.ui(13, color: AppColors.green)),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          // Hand device to P2
          Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.04),
                  border: Border.all(color: AppColors.blue.withValues(alpha: 0.18)),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.person_rounded, color: AppColors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Hand device to',
                          style: AppText.ui(12, color: AppColors.text2)),
                      Text(p2Name,
                          style: AppText.ui(17,
                              weight: FontWeight.w800,
                              color: AppColors.blue)),
                    ])),
              ])),
          const SizedBox(height: 24),
          // Ready button
          GestureDetector(
            onTap: () {
              Haptics.mediumImpact();
              onReady();
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
                      Text("I'm Ready",
                          style: AppText.ui(15,
                              weight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: Colors.white),
                    ]))),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DUEL RESULT SHEET  –  shown after P2 finishes, with final scores
// ═════════════════════════════════════════════════════════════════════════════

class _DuelResultSheet extends StatefulWidget {
  final String p1Name, p2Name;
  final TrackingResult p1Result, p2Result;
  final Future<void> Function() onSave;
  final VoidCallback onDone;

  const _DuelResultSheet({
    required this.p1Name,
    required this.p2Name,
    required this.p1Result,
    required this.p2Result,
    required this.onSave,
    required this.onDone,
  });

  @override
  State<_DuelResultSheet> createState() => _DuelResultSheetState();
}

class _DuelResultSheetState extends State<_DuelResultSheet> {
  bool _saving = false;

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    try {
      await widget.onSave();
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p1pct =
        widget.p1Result.attempts > 0 ? widget.p1Result.made / widget.p1Result.attempts : 0.0;
    final p2pct =
        widget.p2Result.attempts > 0 ? widget.p2Result.made / widget.p2Result.attempts : 0.0;
    final p1wins = p1pct > p2pct;
    final tie = p1pct == p2pct;
    final winner = tie ? 'TIE!' : (p1wins ? widget.p1Name : widget.p2Name);
    const winColor = AppColors.blue;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          // Use Color.alphaBlend so gradient colors are fully opaque
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(AppColors.blue.withValues(alpha: 0.14), AppColors.surface),
              AppColors.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          // Winner banner
          Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              decoration: BoxDecoration(
                  color: winColor.withValues(alpha: 0.08),
                  border: Border.all(color: winColor.withValues(alpha: 0.28)),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(tie ? '🤝' : '🏆', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tie ? "IT'S A TIE" : 'WINNER',
                      style: AppText.ui(9,
                          color: winColor.withValues(alpha: 0.75),
                          letterSpacing: 1.6,
                          weight: FontWeight.w700)),
                  Text(winner,
                      style: AppText.ui(20, weight: FontWeight.w800, color: winColor)),
                ]),
              ])),
          const SizedBox(height: 14),
          // Side-by-side scores — IntrinsicHeight keeps cards equal
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                  child: _PlayerCard(
                      name: widget.p1Name,
                      result: widget.p1Result,
                      color: AppColors.gold,
                      isWinner: !tie && p1wins)),
              const SizedBox(width: 12),
              Expanded(
                  child: _PlayerCard(
                      name: widget.p2Name,
                      result: widget.p2Result,
                      color: AppColors.blue,
                      isWinner: !tie && !p1wins)),
            ]),
          ),
          const SizedBox(height: 24),
          // Action buttons
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: widget.onDone,
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
                onTap: _saving ? null : _handleSave,
                child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(14)),
                    child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Text('Save',
                                style: AppText.ui(14,
                                    weight: FontWeight.w700,
                                    color: Colors.white)))),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Player card within result sheet ─────────────────────────────────────────

class _PlayerCard extends StatelessWidget {
  final String name;
  final TrackingResult result;
  final Color color;
  final bool isWinner;

  const _PlayerCard({
    required this.name,
    required this.result,
    required this.color,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final pct = result.attempts > 0
        ? (result.made / result.attempts * 100).round()
        : 0;

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: isWinner ? color.withValues(alpha: 0.08) : AppColors.surface,
            border: Border.all(
                color: isWinner ? color.withValues(alpha: 0.40) : AppColors.border,
                width: isWinner ? 1.5 : 1),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Always reserves height for WINNER badge — keeps cards equal
          Visibility(
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            visible: isWinner,
            child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('WINNER',
                    style: AppText.ui(9,
                        color: color,
                        letterSpacing: 1.3,
                        weight: FontWeight.w700))),
          ),
          Text(name,
              style: AppText.ui(13, weight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text('$pct%', style: AppText.display(36, color: color)),
          Text('${result.made}/${result.attempts}',
              style: AppText.ui(11, color: AppColors.text3)),
          if (result.swishes > 0)
            Text('${result.swishes} swish ✨',
                style: AppText.ui(11, color: AppColors.green)),
        ]));
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _PlayerNameField extends StatelessWidget {
  final String label;
  final Color color;
  final TextEditingController controller;
  const _PlayerNameField(
      {required this.label,
      required this.color,
      required this.controller});
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
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 13),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 1.5)),
            )),
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
