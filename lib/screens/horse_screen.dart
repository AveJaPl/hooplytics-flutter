import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
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

const _kPurple = Color(0xFFAA5EEF);
const _kPurpleDim = Color(0xFF7B3DBF);

enum _HorsePhase { setup, calling, matching, swapAlert, result }

class HorseScreen extends StatefulWidget {
  const HorseScreen({super.key});
  @override
  State<HorseScreen> createState() => _HorseScreenState();
}

class _HorseScreenState extends State<HorseScreen>
    with SingleTickerProviderStateMixin {
  static const _word = 'HORSE';

  _HorsePhase _phase = _HorsePhase.setup;

  final _p1ctrl = TextEditingController(text: 'Player 1');
  final _p2ctrl = TextEditingController(text: 'Player 2');

  int _p1letters = 0;
  int _p2letters = 0;
  int _callerIndex = 0;
  int _totalRounds = 0;
  late final Stopwatch _stopwatch = Stopwatch();

  final _shotCtrl = TextEditingController();

  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350))
    ..forward();

  String get _callerName => _callerIndex == 0 ? _p1ctrl.text : _p2ctrl.text;
  String get _matcherName => _callerIndex == 0 ? _p2ctrl.text : _p1ctrl.text;
  int get _matcherLetters => _callerIndex == 0 ? _p2letters : _p1letters;

  bool get _gameOver => _p1letters >= 5 || _p2letters >= 5;
  String get _loser => _p1letters >= 5 ? _p1ctrl.text : _p2ctrl.text;
  String get _winner => _p1letters >= 5 ? _p2ctrl.text : _p1ctrl.text;

  @override
  void initState() {
    super.initState();
    // Pre-fill player 1 with user's display name
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
    _shotCtrl.dispose();
    _entry.dispose();
    super.dispose();
  }

  // ── logic ─────────────────────────────────────────────────────────────────

  void _switchPhase(_HorsePhase next) {
    setState(() {
      _phase = next;
      _entry.forward(from: 0);
    });
  }

  void _callerShot(bool made) {
    Haptics.mediumImpact();
    if (made) {
      _totalRounds++;
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _switchPhase(_HorsePhase.matching);
      });
    } else {
      // Caller missed → swap roles, no letter
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          _callerIndex = 1 - _callerIndex;
          _shotCtrl.clear();
          _switchPhase(_HorsePhase.swapAlert);
        }
      });
    }
  }

  void _matcherShot(bool made) {
    Haptics.mediumImpact();
    if (!made) {
      // Matcher missed → gets a letter
      setState(() {
        if (_callerIndex == 0) {
          _p2letters++;
        } else {
          _p1letters++;
        }
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (_gameOver) {
          _switchPhase(_HorsePhase.result);
        } else {
          // Same caller goes again
          _shotCtrl.clear();
          _switchPhase(_HorsePhase.calling);
        }
      });
    } else {
      // Matcher made it → swap caller
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        _callerIndex = 1 - _callerIndex;
        _shotCtrl.clear();
        _switchPhase(_HorsePhase.swapAlert);
      });
    }
  }

  Future<void> _saveSession() async {
    _stopwatch.stop();
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
          'totalRounds': _totalRounds,
        },
        targetShots: 0,
        made: 0,
        swishes: 0,
        attempts: 0,
        bestStreak: 0,
        elapsedSeconds: _elapsedSeconds,
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
      _header('H-O-R-S-E', 'Enter player names'),
      const Spacer(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            // Word preview
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _word.split('').map((l) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(l,
                          style: AppText.display(32,
                              color: AppColors.text3.withValues(alpha: 0.20))),
                    )).toList()),
            const SizedBox(height: 28),
            _nameField('PLAYER 1', _p1ctrl),
            const SizedBox(height: 14),
            _nameField('PLAYER 2', _p2ctrl),
          ])),
      const Spacer(),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: _actionButton('Start H-O-R-S-E', () {
            Haptics.mediumImpact();
            _stopwatch.start();
            _switchPhase(_HorsePhase.calling);
          })),
    ]);
  }

  // ── CALLING phase ─────────────────────────────────────────────────────────

  Widget _buildCalling() {
    return Column(children: [
      _gameHeader(),
      const SizedBox(height: 24),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            // Caller indicator
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: _kPurple.withValues(alpha: 0.06),
                    border: Border.all(color: _kPurple.withValues(alpha: 0.20)),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: _kPurple)),
                  const SizedBox(width: 10),
                  Text('$_callerName is calling',
                      style: AppText.ui(14, weight: FontWeight.w600)),
                  const Spacer(),
                  Text('Caller',
                      style: AppText.ui(12, color: _kPurple)),
                ])),
            const SizedBox(height: 20),
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
                  hintText: 'e.g. "Mid-range from left elbow"',
                  hintStyle: AppText.ui(13, color: AppColors.text3),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(14),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _kPurple, width: 1.5)),
                )),
            const SizedBox(height: 28),
            Text('DID ${_callerName.toUpperCase()} MAKE IT?',
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.3,
                    weight: FontWeight.w700)),
          ]),
        ),
      ),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Row(children: [
            Expanded(child: _outlineButton('MISSED', Icons.close_rounded,
                () => _callerShot(false))),
            const SizedBox(width: 14),
            Expanded(child: _filledButton('MADE IT', Icons.check_rounded,
                () => _callerShot(true))),
          ])),
    ]);
  }

  // ── MATCHING phase ────────────────────────────────────────────────────────

  Widget _buildMatching() {
    final shotDesc = _shotCtrl.text.trim().isEmpty
        ? 'the called shot'
        : '"${_shotCtrl.text.trim()}"';

    return Column(children: [
      _gameHeader(),
      const Spacer(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            // Matcher challenge card
            Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                    color: _kPurple.withValues(alpha: 0.06),
                    border: Border.all(color: _kPurple.withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kPurple.withValues(alpha: 0.12)),
                      child: const Icon(Icons.sports_basketball_rounded,
                          color: _kPurple, size: 24)),
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
                  _letterRow(_matcherLetters, _kPurple),
                ])),
            const SizedBox(height: 28),
            Text('DID ${_matcherName.toUpperCase()} MATCH IT?',
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.3,
                    weight: FontWeight.w700)),
          ])),
      const Spacer(),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Row(children: [
            Expanded(child: _outlineButton('MISSED', Icons.close_rounded,
                () => _matcherShot(false))),
            const SizedBox(width: 14),
            Expanded(child: _filledButton('MATCHED', Icons.check_rounded,
                () => _matcherShot(true))),
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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPurple.withValues(alpha: 0.10),
              ),
              child: const Icon(Icons.swap_horiz_rounded,
                  size: 32, color: _kPurple),
            ),
            const SizedBox(height: 18),
            Text('Switch!',
                style: AppText.display(36, color: AppColors.text1)),
            const SizedBox(height: 10),
            Text('$_callerName is now the caller',
                style: AppText.ui(16, color: AppColors.text2),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            _scoreBoard(),
          ])),
      const Spacer(),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: _actionButton('Continue', () {
            Haptics.mediumImpact();
            _switchPhase(_HorsePhase.calling);
          })),
    ]);
  }

  // ── RESULT ────────────────────────────────────────────────────────────────

  Widget _buildResult() {
    final winnerIsP1 = _p1letters < _p2letters;

    return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Column(children: [
          // Trophy
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kPurple.withValues(alpha: 0.10),
            ),
            child:
                const Icon(Icons.emoji_events_rounded, size: 40, color: _kPurple),
          ),
          const SizedBox(height: 16),
          Text(_winner,
              style: AppText.ui(28, weight: FontWeight.w800, color: _kPurple)),
          Text('wins!', style: AppText.ui(18, color: AppColors.text2)),
          const SizedBox(height: 6),
          Text('$_loser spells H-O-R-S-E',
              style: AppText.ui(14, color: AppColors.text3)),
          const SizedBox(height: 6),
          Text('$_totalRounds rounds played',
              style: AppText.ui(12, color: AppColors.text3)),
          const SizedBox(height: 28),

          // Score cards
          Row(children: [
            Expanded(
                child: _resultCard(
              _p1ctrl.text,
              _p1letters,
              isWinner: winnerIsP1,
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _resultCard(
              _p2ctrl.text,
              _p2letters,
              isWinner: !winnerIsP1,
            )),
          ]),
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
                            color: _kPurple,
                            borderRadius: BorderRadius.circular(14)),
                        child: Center(
                            child: Text('Save',
                                style: AppText.ui(14,
                                    weight: FontWeight.w700,
                                    color: Colors.white)))))),
          ]),
        ]));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _header(String title, String subtitle) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(children: [
          _closeBtn(),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.8,
                    weight: FontWeight.w700)),
            Text(subtitle, style: AppText.ui(16, weight: FontWeight.w700)),
          ]),
        ]));
  }

  Widget _gameHeader() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(children: [
          _closeBtn(),
          const SizedBox(width: 14),
          Expanded(child: _scoreBoard()),
        ]));
  }

  Widget _closeBtn() => GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10)),
          child:
              const Icon(Icons.close_rounded, size: 16, color: AppColors.text2)));

  Widget _scoreBoard() {
    return Row(mainAxisAlignment: MainAxisAlignment.start, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_p1ctrl.text,
            style: AppText.ui(10, color: AppColors.text3),
            overflow: TextOverflow.ellipsis),
        _letterRow(_p1letters, _kPurple, size: 20.0),
      ]),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('vs', style: AppText.ui(12, color: AppColors.text3))),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_p2ctrl.text,
            style: AppText.ui(10, color: AppColors.text3),
            overflow: TextOverflow.ellipsis),
        _letterRow(_p2letters, _kPurpleDim, size: 20.0),
      ]),
    ]);
  }

  Widget _letterRow(int earned, Color color, {double size = 22.0}) {
    return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
            5,
            (i) => Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Text(_word[i],
                    style: AppText.display(size,
                        color: i < earned
                            ? color
                            : AppColors.text3.withValues(alpha: 0.20))))));
  }

  Widget _nameField(String label, TextEditingController ctrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: AppText.ui(9,
              color: AppColors.text3,
              letterSpacing: 1.6,
              weight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextField(
          controller: ctrl,
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
                borderSide: const BorderSide(color: _kPurple, width: 1.5)),
          )),
    ]);
  }

  int get _elapsedSeconds => _stopwatch.elapsed.inSeconds;

  Widget _actionButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          height: 54,
          decoration: BoxDecoration(
              color: _kPurple,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: _kPurple.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5))
              ]),
          child: Center(
              child: Text(label,
                  style: AppText.ui(15,
                      weight: FontWeight.w800, color: Colors.white)))),
    );
  }

  Widget _filledButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          height: 72,
          decoration: BoxDecoration(
              color: _kPurple,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: _kPurple.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: AppText.ui(12,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2)),
          ])),
    );
  }

  Widget _outlineButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          height: 72,
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: AppColors.text2, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: AppText.ui(12,
                    weight: FontWeight.w800,
                    color: AppColors.text2,
                    letterSpacing: 1.2)),
          ])),
    );
  }

  Widget _resultCard(String name, int letters, {required bool isWinner}) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: isWinner
                ? _kPurple.withValues(alpha: 0.06)
                : AppColors.surface,
            border: Border.all(
                color: isWinner
                    ? _kPurple.withValues(alpha: 0.30)
                    : AppColors.border),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isWinner)
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('WINNER',
                    style: AppText.ui(9,
                        color: _kPurple,
                        letterSpacing: 1.3,
                        weight: FontWeight.w700))),
          Text(name,
              style: AppText.ui(14, weight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          _letterRow(letters, _kPurple, size: 24.0),
          const SizedBox(height: 6),
          Text(
              letters == 0
                  ? 'Clean!'
                  : '$letters ${letters == 1 ? "letter" : "letters"}',
              style: AppText.ui(12, color: AppColors.text3)),
        ]));
  }
}
