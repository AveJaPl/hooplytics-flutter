import 'package:flutter/material.dart';
import '../main.dart';
import '../utils/haptics.dart';
import 'history_screen.dart';
import '../widgets/basketball_court_map.dart';
import '../models/shot.dart';
import '../services/session_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  GAME SESSION DETAIL SCREEN
//
//  COLOR PHILOSOPHY  (matches session_detail_screen)
//  ──────────────────────────────────────────────────
//  e.color  → primary accent used EVERYWHERE:
//             hero gradient, big numbers, grade, bars, rings, progress arcs.
//             This is the game-type color set from history — constant.
//
//  AppColors.green / red  → ONLY for:
//    • Shot log dots  (binary make/miss, has legend)
//    • Tiny delta/winner badges
//    • Two-player color distinction in Duel & HORSE (intentional by-player ID)
//
//  Never use red/gold/green to size or grade a performance number.
// ═════════════════════════════════════════════════════════════════════════════

class GameSessionDetailScreen extends StatefulWidget {
  final HistoryEntry entry;
  const GameSessionDetailScreen({super.key, required this.entry});
  @override
  State<GameSessionDetailScreen> createState() => _State();
}

class _State extends State<GameSessionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500))
    ..forward();

  HistoryEntry get e => widget.entry;
  GameSessionData get g => e.gameData!;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // ── computed ──────────────────────────────────────────────────────────────

  /// Grade letter — rendered in e.color, never green/red
  String get _grade {
    if (e.pct == null) return '—';
    final p = e.pct!;
    if (p >= 0.85) return 'S';
    if (p >= 0.75) return 'A';
    if (p >= 0.65) return 'B';
    if (p >= 0.50) return 'C';
    return 'D';
  }

  Future<void> _deleteSession() async {
    final confirmed = await _showDeleteConfirm();
    if (confirmed != true) return;

    try {
      await SessionService().deleteSession(e.originalSession.id!);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirm() async {
    Haptics.mediumImpact();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Session?',
            style: AppText.ui(18, weight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete this session? This cannot be undone.',
          style: AppText.ui(14, color: AppColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppText.ui(14,
                    color: AppColors.text3, weight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: AppText.ui(14,
                    color: AppColors.red, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
        child: SafeArea(
            child: Column(children: [
          _topBar(context),
          Expanded(
              child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _heroCard(),
              const SizedBox(height: 24),
              ..._modeContent(),
              if (e.shotLog != null && e.shotLog!.isNotEmpty && g.modeId != 'duel') ...[
                const SizedBox(height: 24),
                _shotLogSection(),
                const SizedBox(height: 24),
                _accuracyProgression(),
              ],
              const SizedBox(height: 48),
              _deleteButton(),
            ]),
          )),
        ])),
      ),
    );
  }

  Widget _deleteButton() => GestureDetector(
        onTap: _deleteSession,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.red.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
          ),
          child: Center(
            child: Text('Delete Session',
                style: AppText.ui(14,
                    weight: FontWeight.w700, color: AppColors.red)),
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _topBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          GestureDetector(
            onTap: () {
              Haptics.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.close_rounded,
                    size: 17, color: AppColors.text2)),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('GAME SESSION',
                    style: AppText.ui(11,
                        color: AppColors.text2,
                        letterSpacing: 1.4,
                        weight: FontWeight.w800)),
                Text(e.title, style: AppText.ui(15, weight: FontWeight.w700)),
              ])),
          // Badge uses e.color — consistent with session type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: e.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: e.color.withValues(alpha: 0.30))),
            child: Text('GAME',
                style: AppText.ui(11, weight: FontWeight.w800, color: e.color)),
          ),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  HERO CARD
  //  Big %, grade — all in e.color.  No red/gold/green here.
  // ══════════════════════════════════════════════════════════════════════════

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              e.color.withValues(alpha: 0.18),
              e.color.withValues(alpha: 0.04)
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: e.color.withValues(alpha: 0.30)),
            borderRadius: BorderRadius.circular(22)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(e.title, style: AppText.ui(22, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(e.subtitle, style: AppText.ui(13, color: AppColors.text2)),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _chip(Icons.calendar_today_rounded, e.dateLabel),
                  if (e.elapsed.inSeconds > 0)
                    _chip(Icons.timer_outlined, _timeStr(e.elapsed)),
                ]),
              ])),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (e.pct != null) ...[
              // Big % in result-dependent color
              Text(e.pctStr, style: AppText.display(48, color: e.color)),
              Text('${e.made}/${e.attempts}',
                  style: AppText.ui(12, color: AppColors.text2)),
            ] else
              Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: e.color.withValues(alpha: 0.14),
                      border:
                          Border.all(color: e.color.withValues(alpha: 0.35))),
                  child: Icon(e.icon, color: e.color, size: 24)),
            const SizedBox(height: 8),
            if (e.pct != null)
              // Grade badge in e.color
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: e.color.withValues(alpha: 0.12),
                      border:
                          Border.all(color: e.color.withValues(alpha: 0.30))),
                  child: Center(
                      child: Text(_grade,
                          style: AppText.display(20, color: e.color)))),
          ]),
        ]),
      );

  // ── mode router ───────────────────────────────────────────────────────────

  List<Widget> _modeContent() {
    switch (g.modeId) {
      case 'three_point_contest':
        return _threePointContent();
      case 'duel':
        return _duelContent();
      case 'horse':
        return _horseContent();
      case 'beat_the_clock':
        return _btcContent();
      case 'streak_mode':
        return _streakContent();
      case 'pressure_fts':
        return _pressureFtContent();
      case 'hot_spot':
        return _hotSpotContent();
      case 'around_the_world':
        return _atwContent();
      case 'mikan_drill':
        return _mikanContent();
      default:
        return [_genericContent()];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  3-POINT CONTEST
  //  Score/progress in e.color.
  //  Per-rack: use e.color with opacity tiers instead of red/gold/green.
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _threePointContent() {
    final score = g.stats['score'] as int? ?? 0;
    final maxScore = g.stats['maxScore'] as int? ?? 30;
    final made = g.stats['made'] as int? ?? 0;
    final racks =
        (g.stats['rackScores'] as List?)?.cast<int>() ?? List.filled(5, 0);
    final pct = maxScore > 0 ? score / maxScore : 0.0;

    return [
      _label('FINAL SCORE'),
      Container(
          padding: const EdgeInsets.all(22),
          decoration: _box(),
          child: Column(children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Score in e.color
                Text('$score', style: AppText.display(64, color: e.color)),
                Text('points out of $maxScore',
                    style: AppText.ui(13, color: AppColors.text2)),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$made',
                    style: AppText.display(36, color: AppColors.text1)),
                Text('balls made',
                    style: AppText.ui(11, color: AppColors.text3)),
              ]),
            ]),
            const SizedBox(height: 16),
            ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.borderSub,
                    valueColor: AlwaysStoppedAnimation(e.color),
                    minHeight: 9)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('NBA Record: 27 pts (Hodges, 1991)',
                  style: AppText.ui(10, color: AppColors.text3)),
              Text('${(pct * 100).round()}% of max',
                  style:
                      AppText.ui(10, color: e.color, weight: FontWeight.w600)),
            ]),
          ])),
      const SizedBox(height: 16),
      _label('RACK BREAKDOWN'),
      Row(
          children: List.generate(5, (i) {
        final rs = i < racks.length ? racks[i] : 0;
        final rp = rs / 6.0;
        // Opacity tiers of e.color — no red/gold/green
        final rAlpha = rp >= 0.67
            ? 1.0
            : rp >= 0.50
                ? 0.60
                : 0.35;
        final rColor = e.color.withValues(alpha: rAlpha);
        return Expanded(
            child: Padding(
          padding: EdgeInsets.only(right: i < 4 ? 8 : 0),
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text('$rs', style: AppText.display(26, color: rColor)),
                Text('/6', style: AppText.ui(10, color: AppColors.text3)),
                const SizedBox(height: 4),
                Text('R${i + 1}',
                    style: AppText.ui(9,
                        color: AppColors.text3, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                            value: rp,
                            backgroundColor: AppColors.borderSub,
                            valueColor: AlwaysStoppedAnimation(rColor),
                            minHeight: 3))),
              ])),
        ));
      })),
      const SizedBox(height: 14),
      _twoStatCompare('Your Score', '$score pts', 'NBA Avg', '~18 pts'),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DUEL
  //  Exception: two-player colors (gold vs blue) are intentional identifiers.
  //  Winner badge uses a small green tick — acceptable binary indicator.
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _duelContent() {
    final p1n = g.stats['p1Name'] as String? ?? 'P1';
    final p2n = g.stats['p2Name'] as String? ?? 'P2';
    final p1m = g.stats['p1Made'] as int? ?? 0;
    final p1a = g.stats['p1Attempts'] as int? ?? 0;
    final p1sw = g.stats['p1Swishes'] as int? ?? 0;
    final p2m = g.stats['p2Made'] as int? ?? 0;
    final p2a = g.stats['p2Attempts'] as int? ?? 0;
    final p2sw = g.stats['p2Swishes'] as int? ?? 0;
    final win = g.stats['winner'] as String? ?? '—';
    // Backward-compatible: old entries store List<bool>, new store List<int> (0/1/2)
    final p1logRaw = (g.stats['p1Log'] as List?) ?? [];
    final p2logRaw = (g.stats['p2Log'] as List?) ?? [];
    final p1log = p1logRaw.map(_normaliseShot).toList();
    final p2log = p2logRaw.map(_normaliseShot).toList();
    final p1pct = p1a > 0 ? p1m / p1a : 0.0;
    final p2pct = p2a > 0 ? p2m / p2a : 0.0;
    final p1wins = p1pct >= p2pct;

    return [
      _label('RESULT'),
      Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                e.color.withValues(alpha: 0.15),
                e.color.withValues(alpha: 0.03)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: e.color.withValues(alpha: 0.27)),
              borderRadius: BorderRadius.circular(18)),
          child: Center(
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🏆 ', style: TextStyle(fontSize: 24)),
            Text(win == 'TIE' ? "IT'S A TIE" : '$win wins!',
                style: AppText.ui(22, weight: FontWeight.w800, color: e.color)),
          ]))),
      const SizedBox(height: 16),
      _label('HEAD TO HEAD'),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _playerCard(p1n, p1m, p1a, p1sw, e.color, p1wins)),
          const SizedBox(width: 12),
          Expanded(child: _playerCard(p2n, p2m, p2a, p2sw, e.color, !p1wins)),
        ]),
      ),
      const SizedBox(height: 16),
      _label('DIRECT COMPARISON'),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: _box(),
          child: Column(children: [
            _duelCompareRow('Accuracy', '${(p1pct * 100).round()}%', '${(p2pct * 100).round()}%', e.color, e.color, p1pct >= p2pct, p2pct >= p1pct),
            const SizedBox(height: 10),
            _duelCompareRow('Made', '$p1m', '$p2m', e.color, e.color, p1m >= p2m, p2m >= p1m),
            if (p1sw > 0 || p2sw > 0) ...[
              const SizedBox(height: 10),
              _duelCompareRow('Swishes ✨', '$p1sw', '$p2sw', e.color, e.color, p1sw >= p2sw, p2sw >= p1sw),
            ],
          ])),
      const SizedBox(height: 16),
      if (p1log.isNotEmpty || p2log.isNotEmpty) ...[
        _label('SHOT LOGS'),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Shared legend — same style as live sessions
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _duelLegendDot(e.color, 'swish', filled: true),
              const SizedBox(width: 16),
              _duelLegendDot(e.color, 'made', filled: false),
              const SizedBox(width: 16),
              _duelLegendDot(AppColors.border, 'miss', filled: false),
            ]),
            if (p1log.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(p1n,
                  style: AppText.ui(11,
                      color: AppColors.text2, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              _duelDots(p1log, e.color),
            ],
            if (p2log.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(p2n,
                  style: AppText.ui(11,
                      color: AppColors.text2, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              _duelDots(p2log, e.color),
            ],
          ]),
        ),
      ],
    ];
  }

  /// Normalise log entry: bool (old format) or int (new format 0/1/2)
  /// Returns 0=miss, 1=make, 2=swish
  int _normaliseShot(dynamic v) {
    if (v is bool) return v ? 1 : 0;
    if (v is int) return v;
    return 0;
  }

  Widget _playerCard(String name, int made, int att, int swishes,
      Color color, bool winner) {
    final pct = att > 0 ? made / att : 0.0;
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: winner ? color.withValues(alpha: 0.08) : color.withValues(alpha: 0.03),
            border: Border.all(
                color: winner ? color.withValues(alpha: 0.45) : color.withValues(alpha: 0.18),
                width: winner ? 1.5 : 1),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Visibility(maintainSize) keeps both cards equal height
          Visibility(
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            visible: winner,
            child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('WINNER',
                    style: AppText.ui(8,
                        color: color,
                        letterSpacing: 1.2,
                        weight: FontWeight.w800))),
          ),
          Text(name,
              style: AppText.ui(13, weight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text('${(pct * 100).round()}%',
              style: AppText.display(34, color: color)),
          Text('$made/$att', style: AppText.ui(11, color: AppColors.text3)),
          if (swishes > 0)
            Text('$swishes swish ✨',
                style: AppText.ui(11, color: AppColors.green)),
        ]));
  }

  // Dots matching live session style: swish=filled, make=outline, miss=gray outline
  Widget _duelDots(List<int> log, Color modeColor) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: log.map((v) {
        final isMiss = v == 0;
        final isSwish = v == 2;
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSwish ? modeColor : Colors.transparent,
            border: Border.all(
              color: isMiss ? AppColors.border : modeColor,
              width: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _duelLegendDot(Color color, String label, {required bool filled}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: AppText.ui(11, color: AppColors.text2)),
    ]);
  }

  Widget _duelCompareRow(String label, String v1, String v2, Color c1, Color c2, bool hi1, bool hi2) {
    return Row(children: [
      Expanded(
          child: Text(v1,
              textAlign: TextAlign.center,
              style: AppText.display(22, color: hi1 ? c1 : AppColors.text3))),
      Expanded(
          child: Text(label,
              textAlign: TextAlign.center,
              style: AppText.ui(11, color: AppColors.text3, weight: FontWeight.w700))),
      Expanded(
          child: Text(v2,
              textAlign: TextAlign.center,
              style: AppText.display(22, color: hi2 ? c2 : AppColors.text3))),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  H-O-R-S-E
  //  Two-player letter colors intentional (identity not performance).
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _horseContent() {
    final p1n = g.stats['p1Name'] as String? ?? 'P1';
    final p2n = g.stats['p2Name'] as String? ?? 'P2';
    final p1l = g.stats['p1Letters'] as int? ?? 0;
    final p2l = g.stats['p2Letters'] as int? ?? 0;
    final win = g.stats['winner'] as String? ?? '—';
    final loser = g.stats['loser'] as String? ?? '—';
    final rounds = g.stats['totalRounds'] as int? ?? 0;
    const word = 'HORSE';

    return [
      _label('RESULT'),
      Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                e.color.withValues(alpha: 0.16),
                e.color.withValues(alpha: 0.04)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: e.color.withValues(alpha: 0.28)),
              borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            const Text('🎯', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text('$win wins!',
                style: AppText.ui(24, weight: FontWeight.w800, color: e.color)),
            const SizedBox(height: 4),
            Text('$loser spells H-O-R-S-E',
                style: AppText.ui(14, color: AppColors.text2)),
            const SizedBox(height: 10),
            Text('$rounds rounds played',
                style: AppText.ui(12, color: AppColors.text2)),
          ])),
      const SizedBox(height: 16),
      _label('LETTERS'),
      Row(children: [
        // P1 = e.color letters (earned = lit, unearned = dim)
        Expanded(
            child: Container(
                padding: const EdgeInsets.all(16),
                decoration: _box(),
                child: Column(children: [
                  Text(p1n,
                      style: AppText.ui(13, weight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                          5,
                          (i) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: Text(word[i],
                                  style: AppText.display(26,
                                      color: i < p1l
                                          ? e.color
                                          : AppColors.text3
                                              .withValues(alpha: 0.18)))))),
                  const SizedBox(height: 6),
                  Text('$p1l / 5 letters',
                      style: AppText.ui(12,
                          color: AppColors.text2, weight: FontWeight.w600)),
                ]))),
        const SizedBox(width: 12),
        // P2 = neutral (opponent), earned letters in text2
        Expanded(
            child: Container(
                padding: const EdgeInsets.all(16),
                decoration: _box(),
                child: Column(children: [
                  Text(p2n,
                      style: AppText.ui(13, weight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                          5,
                          (i) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: Text(word[i],
                                  style: AppText.display(26,
                                      color: i < p2l
                                          ? AppColors.text2
                                          : AppColors.text3
                                              .withValues(alpha: 0.18)))))),
                  const SizedBox(height: 6),
                  Text('$p2l / 5 letters',
                      style: AppText.ui(10, color: AppColors.text3)),
                ]))),
      ]),
      const SizedBox(height: 14),
      _infoRow(Icons.timer_outlined, 'Duration', _timeStr(e.elapsed)),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BEAT THE CLOCK
  //  All stats in e.color / neutral. Removed dynamic pc2 color.
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _btcContent() {
    final made = g.stats['made'] as int? ?? 0;
    final att = g.stats['attempts'] as int? ?? 0;
    final pct = att > 0 ? made / att : 0.0;

    return [
      _label('60-SECOND RESULTS'),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: _box(),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              // MADE and ACC both use e.color — no performance-based coloring
              _bigStat('$made', 'MADE', e.color),
              _vDiv(),
              _bigStat('$att', 'SHOTS', AppColors.text1),
              _vDiv(),
              _bigStat('${(pct * 100).round()}%', 'ACC', e.color),
            ]),
            const SizedBox(height: 18),
            const Divider(height: 1, color: AppColors.borderSub),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Shot rate',
                        style: AppText.ui(12, color: AppColors.text2)),
                    const SizedBox(height: 6),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            value: (att / 50).clamp(0, 1),
                            backgroundColor: AppColors.borderSub,
                            valueColor: AlwaysStoppedAnimation(e.color),
                            minHeight: 6)),
                  ])),
              const SizedBox(width: 16),
              Text('$att / 60s',
                  style:
                      AppText.ui(14, weight: FontWeight.w700, color: e.color)),
            ]),
          ])),
      const SizedBox(height: 14),
      _twoStatCompare('Your shots', '$att shots', 'Target', '30+ shots'),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STREAK MODE
  //  Streak number uses e.color. Removed red streak icon.
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _streakContent() {
    final best = g.stats['bestStreak'] as int? ?? 0;
    final made = g.stats['totalMade'] as int? ?? 0;
    final total = g.stats['totalAttempts'] as int? ?? 0;
    final pct = total > 0 ? made / total : 0.0;

    return [
      _label('STREAK RESULTS'),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: _box(),
          child: Column(children: [
            Row(children: [
              Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: e.color.withValues(alpha: 0.12),
                      border:
                          Border.all(color: e.color.withValues(alpha: 0.25))),
                  child: Icon(Icons.local_fire_department_rounded,
                      color: e.color, size: 28)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Best Streak',
                    style: AppText.ui(12, color: AppColors.text2)),
                // Streak number in e.color
                Text('$best', style: AppText.display(52, color: e.color)),
                Text('consecutive makes',
                    style: AppText.ui(11, color: AppColors.text3)),
              ]),
            ]),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.borderSub),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _bigStat('$made', 'MADE', e.color),
              _vDiv(),
              _bigStat('$total', 'SHOTS', AppColors.text1),
              _vDiv(),
              _bigStat('${(pct * 100).round()}%', 'ACC', e.color),
            ]),
            if (best >= 10) ...[
              const SizedBox(height: 14),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                      color: e.color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: e.color.withValues(alpha: 0.18))),
                  child: Row(children: [
                    const Text('⭐ ', style: TextStyle(fontSize: 14)),
                    Expanded(
                        child: Text('$best+ streak — elite consistency!',
                            style: AppText.ui(12, color: e.color))),
                  ])),
            ],
          ])),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PRESSURE FREE THROWS
  //  Level indicators and bars all in e.color.
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _pressureFtContent() {
    final levels = g.stats['levelsCleared'] as int? ?? 0;
    final total = g.stats['totalLevels'] as int? ?? 5;
    final made = g.stats['made'] as int? ?? 0;
    final att = g.stats['attempts'] as int? ?? 0;
    final pct = att > 0 ? made / att : 0.0;
    final done = levels >= total;

    return [
      if (done) ...[
        _completedBanner('All $total Levels Cleared! 🏆'),
        const SizedBox(height: 14),
      ],
      _label('LEVEL PROGRESS'),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: _box(),
          child: Column(children: [
            Row(
                children: List.generate(total, (i) {
              final d = i < levels;
              return Expanded(
                  child: Padding(
                      padding: EdgeInsets.only(right: i < total - 1 ? 8 : 0),
                      child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                              color: d
                                  ? e.color.withValues(alpha: 0.12)
                                  : AppColors.bg,
                              border: Border.all(
                                  color: d
                                      ? e.color.withValues(alpha: 0.32)
                                      : AppColors.border),
                              borderRadius: BorderRadius.circular(10)),
                          child: Center(
                              child: d
                                  ? Icon(Icons.check_rounded,
                                      size: 18, color: e.color)
                                  : Text('${i + 1}',
                                      style: AppText.display(18,
                                          color: AppColors.text3))))));
            })),
            const SizedBox(height: 16),
            ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: levels / total,
                    backgroundColor: AppColors.borderSub,
                    valueColor: AlwaysStoppedAnimation(e.color),
                    minHeight: 6)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _bigStat('$levels/$total', 'LEVELS', e.color),
              _vDiv(),
              _bigStat('$made', 'MADE', e.color),
              _vDiv(),
              _bigStat('${(pct * 100).round()}%', 'ACC', e.color),
            ]),
          ])),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HOT SPOT
  //  Per-spot bars: e.color with opacity gradient (stronger = more opaque).
  //  Avoids per-spot red/gold/green while still showing relative performance.
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _hotSpotContent() {
    const spots = [
      'Left Corner',
      'Left Wing',
      'Top of Arc',
      'Right Wing',
      'Right Corner'
    ];
    final made = e.made ?? 0;
    final att = e.attempts ?? 0;

    return [
      _label('COURT MAP'),
      BasketballCourtMap(
        themeColor: e.color,
        mode: CourtMapMode.stats,
        spots: const [],
      ),
      const SizedBox(height: 14),
      _label('SPOT PERFORMANCE'),
      Container(
          padding: const EdgeInsets.all(16),
          decoration: _box(),
          child: Column(
            children: spots.asMap().entries.map((en) {
              final spotMade =
                  (made / 5 * (0.6 + en.key * 0.09)).round().clamp(0, 10);
              final sp = spotMade / 10.0;
              // Opacity tier of e.color — no red/gold/green
              final alpha = 0.35 + sp * 0.65; // 0.35 → 1.0 based on performance
              final spotColor = e.color.withValues(alpha: alpha);
              return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: e.color.withValues(alpha: sp * 0.15),
                            border: Border.all(
                                color: e.color.withValues(alpha: sp * 0.35))),
                        child: Center(
                            child: Text('${en.key + 1}',
                                style: AppText.ui(11,
                                    weight: FontWeight.w700,
                                    color: spotColor)))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(en.value,
                                    style: AppText.ui(13,
                                        weight: FontWeight.w600)),
                                Text('$spotMade/10',
                                    style: AppText.ui(12,
                                        weight: FontWeight.w700,
                                        color: spotColor)),
                              ]),
                          const SizedBox(height: 5),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                  value: sp,
                                  backgroundColor: AppColors.borderSub,
                                  valueColor: AlwaysStoppedAnimation(spotColor),
                                  minHeight: 5)),
                        ])),
                  ]));
            }).toList(),
          )),
      const SizedBox(height: 14),
      _twoStatCompare('Total made', '$made', 'Total shots', '$att'),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  AROUND THE WORLD
  //  Cleared spot indicators in e.color.
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _atwContent() {
    final cleared = g.stats['spotsCleared'] as int? ?? 0;
    final total = g.stats['totalSpots'] as int? ?? 7;
    final made = g.stats['made'] as int? ?? 0;
    final att = g.stats['attempts'] as int? ?? 0;
    final completed = g.stats['completed'] as bool? ?? false;
    const spots = [
      'L. Corner',
      'L. Wing',
      'L. Elbow',
      'Free Throw',
      'R. Elbow',
      'R. Wing',
      'R. Corner'
    ];

    return [
      if (completed) ...[
        _completedBanner('Around the World Complete! 🌍'),
        const SizedBox(height: 14)
      ],
      _label('SPOT PROGRESS'),
      Container(
          padding: const EdgeInsets.all(18),
          decoration: _box(),
          child: Column(children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(total, (i) {
                  final d = i < cleared;
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: d
                                ? e.color.withValues(alpha: 0.14)
                                : AppColors.borderSub.withValues(alpha: 0.5),
                            border: Border.all(
                                color: d
                                    ? e.color.withValues(alpha: 0.42)
                                    : AppColors.border)),
                        child: Center(
                            child: d
                                ? Icon(Icons.check_rounded,
                                    size: 16, color: e.color)
                                : Text('${i + 1}',
                                    style: AppText.ui(11,
                                        color: AppColors.text3,
                                        weight: FontWeight.w700)))),
                    const SizedBox(height: 4),
                    SizedBox(
                        width: 38,
                        child: Text(spots[i].split(' ').last.trim(),
                            style: AppText.ui(8, color: AppColors.text3),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis)),
                  ]);
                })),
            const SizedBox(height: 16),
            ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: cleared / total,
                    backgroundColor: AppColors.borderSub,
                    valueColor: AlwaysStoppedAnimation(e.color),
                    minHeight: 7)),
            const SizedBox(height: 8),
            Text('$cleared of $total spots completed',
                style: AppText.ui(12, color: AppColors.text3)),
          ])),
      const SizedBox(height: 14),
      _twoStatCompare('Makes', '$made', 'Attempts', '$att'),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MIKAN DRILL
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _mikanContent() {
    final reps = e.made ?? 0;
    final made = g.stats['made'] as int? ?? reps;

    return [
      _label('DRILL RESULTS'),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: _box(),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _bigStat('$reps', 'REPS', e.color),
              _vDiv(),
              _bigStat('$made', 'MAKES', e.color),
              _vDiv(),
              _bigStat('20', 'TARGET', AppColors.text3),
            ]),
            const SizedBox(height: 18),
            ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: (reps / 20).clamp(0, 1),
                    backgroundColor: AppColors.borderSub,
                    valueColor: AlwaysStoppedAnimation(e.color),
                    minHeight: 7)),
            const SizedBox(height: 8),
            Text('${(reps / 20 * 100).round()}% of target completed',
                style: AppText.ui(12, color: AppColors.text3)),
          ])),
      const SizedBox(height: 14),
      _infoRow(Icons.info_outline_rounded, 'Focus',
          'Soft touch & footwork around the basket'),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GENERIC
  // ══════════════════════════════════════════════════════════════════════════

  Widget _genericContent() {
    if (e.made == null) return const SizedBox.shrink();
    return Column(children: [
      Container(
          padding: const EdgeInsets.all(20),
          decoration: _box(),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _bigStat('${e.made}', 'MADE', e.color),
              _vDiv(),
              _bigStat(
                  '${(e.hoopSession?.swishCount ?? 0) > 0 ? e.hoopSession!.swishCount : (e.originalSession.swishes)}',
                  'SWISH',
                  e.color),
            ]),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _bigStat('${e.attempts! - e.made!}', 'MISSED', AppColors.text2),
              _vDiv(),
              _bigStat('${e.attempts}', 'TOTAL', AppColors.text1),
            ]),
          ])),
      const SizedBox(height: 14),
      _insightsGrid(),
      _label('COURT MAP'),
      BasketballCourtMap(
        themeColor: e.color,
        mode: CourtMapMode.stats,
        spots: const [],
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ACCURACY PROGRESSION  —  e.color line
  // ══════════════════════════════════════════════════════════════════════════

  Widget _accuracyProgression() {
    final log = e.shotLog!;
    final points = <double>[];
    int m = 0;
    for (int i = 0; i < log.length; i++) {
      if (log[i] != ShotResult.miss) m++;
      points.add(m / (i + 1));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('ACCURACY PROGRESSION'),
      Container(
          height: 130,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: _box(),
          child: CustomPaint(
              size: Size.infinite,
              painter: _LinePainter(points: points, color: e.color))),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SHOT LOG DOTS
  //  green=made / dim=missed with legend — only place green appears outside Duel.
  // ══════════════════════════════════════════════════════════════════════════

  Widget _shotLogSection() {
    final log = e.shotLog!;
    final modeColor = e.color;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('SHOT LOG'),
      Container(
          padding: const EdgeInsets.all(18),
          decoration: _box(),
          child: Column(children: [
            Wrap(
                spacing: 6,
                runSpacing: 6,
                children: log
                    .take(60)
                    .map((r) => Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: r == ShotResult.swish ? modeColor : Colors.transparent,
                          border: Border.all(
                            color: r == ShotResult.miss
                                ? AppColors.border
                                : modeColor,
                            width: 1.5,
                          ),
                        )))
                    .toList()),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _legendDot(modeColor, 'made', isOutline: true),
              const SizedBox(width: 16),
              _legendDot(modeColor, 'swish', isOutline: false),
              const SizedBox(width: 16),
              _legendDot(AppColors.border, 'missed', isOutline: true),
            ]),
          ])),
    ]);
  }

  Widget _insightsGrid() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('GAME INSIGHTS'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
        children: [
          _insightCard('MAX STREAK', '${e.hoopSession?.maxStreak ?? 0}',
              Icons.local_fire_department_rounded, e.color),
          _insightCard('SWISH STREAK', '${e.hoopSession?.swishStreak ?? 0}',
              Icons.stars_rounded, e.color),
        ],
      ),
    ]);
  }

  Widget _insightCard(
      String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 6),
          Text(label,
              style: AppText.ui(10,
                  color: AppColors.text2,
                  weight: FontWeight.w800,
                  letterSpacing: 0.2)),
        ]),
        const Spacer(),
        Text(value,
            style: AppText.ui(16, color: AppColors.text1, weight: FontWeight.w800)),
      ]),
    );
  }

  Widget _legendDot(Color color, String label, {required bool isOutline}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOutline ? Colors.transparent : color,
          border: Border.all(color: color, width: 1.5),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: AppText.ui(11, color: AppColors.text2)),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Text(t,
              style: AppText.ui(11,
                  color: AppColors.text2,
                  letterSpacing: 1.4,
                  weight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: AppColors.borderSub)),
        ]),
      );

  BoxDecoration _box() => BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16));

  Widget _chip(IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.text2),
        const SizedBox(width: 5),
        Text(label, style: AppText.ui(11, color: AppColors.text2)),
      ]));

  Widget _bigStat(String v, String l, Color c) => Column(children: [
        Text(v, style: AppText.ui(22, weight: FontWeight.w800, color: c)),
        Text(l,
            style: AppText.ui(11,
                color: AppColors.text2,
                letterSpacing: 0.5,
                weight: FontWeight.w700)),
      ]);

  Widget _vDiv() => Container(width: 1, height: 36, color: AppColors.borderSub);


  Widget _infoRow(IconData icon, String label, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: _box(),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.text2),
        const SizedBox(width: 10),
        Text(label, style: AppText.ui(13, color: AppColors.text2)),
        const Spacer(),
        Flexible(
            child: Text(value,
                style: AppText.ui(13, weight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
      ]));

  /// Comparison row — left value in e.color, right in neutral text2
  Widget _twoStatCompare(String l1, String v1, String l2, String v2) =>
      Container(
          padding: const EdgeInsets.all(16),
          decoration: _box(),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(l1,
                      style: AppText.ui(12,
                          color: AppColors.text2, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(v1,
                      style: AppText.ui(18,
                          weight: FontWeight.w800, color: e.color)),
                ])),
            Container(
                width: 1,
                height: 40,
                color: AppColors.borderSub,
                margin: const EdgeInsets.symmetric(horizontal: 16)),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                  Text(l2,
                      style: AppText.ui(12,
                          color: AppColors.text2, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(v2,
                      style: AppText.ui(18,
                          weight: FontWeight.w800, color: AppColors.text2)),
                ])),
          ]));

  Widget _completedBanner(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: e.color.withValues(alpha: 0.08),
          border: Border.all(color: e.color.withValues(alpha: 0.26)),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.military_tech_rounded, color: e.color, size: 18),
        const SizedBox(width: 8),
        Text(text,
            style: AppText.ui(13, weight: FontWeight.w700, color: e.color)),
      ]));

  String _timeStr(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  LINE CHART PAINTER
// ═════════════════════════════════════════════════════════════════════════════

class _LinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  const _LinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final n = points.length;
    final dx = size.width / (n - 1);
    final path = Path(), fill = Path();

    for (int i = 0; i < n; i++) {
      final x = i * dx, y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(0, size.height);
        fill.lineTo(x, y);
      } else {
        final px = (i - 1) * dx, py = size.height * (1 - points[i - 1]);
        path.quadraticBezierTo(px, py, (px + x) / 2, (py + y) / 2);
        fill.quadraticBezierTo(px, py, (px + x) / 2, (py + y) / 2);
        if (i == n - 1) {
          path.lineTo(x, y);
          fill.lineTo(x, y);
        }
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    final avg = points.reduce((a, b) => a + b) / n;
    canvas.drawLine(
        Offset(0, size.height * (1 - avg)),
        Offset(size.width, size.height * (1 - avg)),
        Paint()
          ..color = AppColors.text3.withValues(alpha: 0.15)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke);

    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    final lx = (n - 1) * dx, ly = size.height * (1 - points.last);
    canvas.drawCircle(Offset(lx, ly), 4.5, Paint()..color = color);
    canvas.drawCircle(
        Offset(lx, ly),
        4.5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_) => false;
}
