import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'history_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  GAME SESSION DETAIL SCREEN
//  One screen for all game modes — routes to mode-specific section widgets.
// ═════════════════════════════════════════════════════════════════════════════

class GameSessionDetailScreen extends StatefulWidget {
  final HistoryEntry entry;
  const GameSessionDetailScreen({super.key, required this.entry});
  @override
  State<GameSessionDetailScreen> createState() => _State();
}

class _State extends State<GameSessionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500))
    ..forward();

  HistoryEntry get e => widget.entry;
  GameSessionData get g => e.gameData!;

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  // ── computed ──────────────────────────────────────────────────────────────

  Color get pctColor {
    final p = e.pct ?? 0;
    if (p >= 0.70) return AppColors.green;
    if (p >= 0.50) return AppColors.gold;
    return AppColors.red;
  }

  String get grade {
    if (e.pct == null) return '—';
    final p = e.pct!;
    if (p >= 0.85) return 'S';
    if (p >= 0.75) return 'A';
    if (p >= 0.65) return 'B';
    if (p >= 0.50) return 'C';
    return 'D';
  }

  Color get gradeColor {
    final p = e.pct ?? 0;
    if (p >= 0.75) return AppColors.green;
    if (p >= 0.50) return AppColors.gold;
    return AppColors.red;
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
              if (e.shotLog != null && e.shotLog!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _accuracyProgression(),
                const SizedBox(height: 24),
                _shotLogSection(),
              ],
            ]),
          )),
        ])),
      ),
    );
  }

  // ── top bar ───────────────────────────────────────────────────────────────

  Widget _topBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
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
                    style: AppText.ui(9,
                        color: AppColors.text3,
                        letterSpacing: 1.8,
                        weight: FontWeight.w700)),
                Text(e.title, style: AppText.ui(15, weight: FontWeight.w700)),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: e.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: e.color.withValues(alpha: 0.30))),
            child: Text('GAME',
                style: AppText.ui(9, weight: FontWeight.w800, color: e.color)),
          ),
        ]),
      );

  // ── hero card ─────────────────────────────────────────────────────────────

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              e.color.withValues(alpha: 0.20),
              e.color.withValues(alpha: 0.05)
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: e.color.withValues(alpha: 0.32)),
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
              Text(e.pctStr, style: AppText.display(48, color: pctColor)),
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
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: gradeColor.withValues(alpha: 0.10),
                      border: Border.all(
                          color: gradeColor.withValues(alpha: 0.32))),
                  child: Center(
                      child: Text(grade,
                          style: AppText.display(20, color: gradeColor)))),
          ]),
        ]),
      );

  // ── mode content router ───────────────────────────────────────────────────

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
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _threePointContent() {
    final score = g.stats['score'] as int? ?? 0;
    final maxScore = g.stats['maxScore'] as int? ?? 30;
    final made = g.stats['made'] as int? ?? 0;
    final rackScores =
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
                Text('$score',
                    style: AppText.display(64, color: AppColors.gold)),
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
                    valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                    minHeight: 9)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('NBA Record: 27 pts (Hodges, 1991)',
                  style: AppText.ui(10, color: AppColors.text3)),
              Text('${(pct * 100).round()}% of max',
                  style: AppText.ui(10,
                      color: AppColors.gold, weight: FontWeight.w600)),
            ]),
          ])),
      const SizedBox(height: 16),
      _label('RACK BREAKDOWN'),
      Row(
          children: List.generate(5, (i) {
        final rs = i < rackScores.length ? rackScores[i] : 0;
        final rp = rs / 6.0;
        final rc = rp >= 0.67
            ? AppColors.green
            : rp >= 0.50
                ? AppColors.gold
                : AppColors.red;
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
                Text('$rs', style: AppText.display(26, color: rc)),
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
                            valueColor: AlwaysStoppedAnimation(rc),
                            minHeight: 3))),
              ])),
        ));
      })),
      const SizedBox(height: 14),
      _twoStatCompare(
          'Your Score', '$score pts', 'NBA Avg', '~18 pts', AppColors.gold),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DUEL
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _duelContent() {
    final p1n = g.stats['p1Name'] as String? ?? 'P1';
    final p2n = g.stats['p2Name'] as String? ?? 'P2';
    final p1m = g.stats['p1Made'] as int? ?? 0;
    final p1a = g.stats['p1Attempts'] as int? ?? 0;
    final p2m = g.stats['p2Made'] as int? ?? 0;
    final p2a = g.stats['p2Attempts'] as int? ?? 0;
    final win = g.stats['winner'] as String? ?? '—';
    final p1log = (g.stats['p1Log'] as List?)?.cast<bool>() ?? [];
    final p2log = (g.stats['p2Log'] as List?)?.cast<bool>() ?? [];
    final p1pct = p1a > 0 ? p1m / p1a : 0.0;
    final p2pct = p2a > 0 ? p2m / p2a : 0.0;
    final p1wins = p1pct >= p2pct;

    return [
      _label('RESULT'),
      Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.gold.withValues(alpha: 0.16),
                AppColors.gold.withValues(alpha: 0.03)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
              borderRadius: BorderRadius.circular(18)),
          child: Center(
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🏆 ', style: TextStyle(fontSize: 24)),
            Text('$win wins!',
                style: AppText.ui(22,
                    weight: FontWeight.w800, color: AppColors.gold)),
          ]))),
      const SizedBox(height: 16),
      _label('HEAD TO HEAD'),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: _playerCard(p1n, p1m, p1a, p1log, AppColors.gold, p1wins)),
        const SizedBox(width: 12),
        Expanded(
            child: _playerCard(p2n, p2m, p2a, p2log, AppColors.blue, !p1wins)),
      ]),
      const SizedBox(height: 16),
      _label('ACCURACY COMPARISON'),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: _box(),
          child: Column(children: [
            _accBar(p1n, p1pct, AppColors.gold),
            const SizedBox(height: 12),
            _accBar(p2n, p2pct, AppColors.blue),
          ])),
    ];
  }

  Widget _playerCard(String name, int made, int att, List<bool> log,
      Color color, bool winner) {
    final pct = att > 0 ? made / att : 0.0;
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: winner ? color.withValues(alpha: 0.07) : AppColors.surface,
            border: Border.all(
                color:
                    winner ? color.withValues(alpha: 0.40) : AppColors.border,
                width: winner ? 1.5 : 1),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (winner)
            Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('WINNER',
                    style: AppText.ui(8,
                        color: color,
                        letterSpacing: 1.2,
                        weight: FontWeight.w800))),
          Text(name,
              style: AppText.ui(13, weight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text('${(pct * 100).round()}%',
              style: AppText.display(34, color: color)),
          Text('$made/$att', style: AppText.ui(11, color: AppColors.text3)),
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
                              : AppColors.red.withValues(alpha: 0.45))))
                  .toList()),
        ]));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  H-O-R-S-E
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
                const Color(0xFFAA5EEF).withValues(alpha: 0.18),
                const Color(0xFFAA5EEF).withValues(alpha: 0.04)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(
                  color: const Color(0xFFAA5EEF).withValues(alpha: 0.30)),
              borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            const Text('🎯', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text('$win wins!',
                style: AppText.ui(24,
                    weight: FontWeight.w800, color: const Color(0xFFAA5EEF))),
            const SizedBox(height: 4),
            Text('$loser spells H-O-R-S-E',
                style: AppText.ui(14, color: AppColors.text2)),
            const SizedBox(height: 10),
            Text('$rounds rounds played',
                style: AppText.ui(12, color: AppColors.text3)),
          ])),
      const SizedBox(height: 16),
      _label('LETTERS'),
      Row(children: [
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
                                          ? const Color(0xFFAA5EEF)
                                          : AppColors.text3
                                              .withValues(alpha: 0.20)))))),
                  const SizedBox(height: 6),
                  Text('$p1l / 5 letters',
                      style: AppText.ui(10, color: AppColors.text3)),
                ]))),
        const SizedBox(width: 12),
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
                                          ? const Color(0xFFFF7A5C)
                                          : AppColors.text3
                                              .withValues(alpha: 0.20)))))),
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
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _btcContent() {
    final made = g.stats['made'] as int? ?? 0;
    final att = g.stats['attempts'] as int? ?? 0;
    final pct = att > 0 ? made / att : 0.0;
    final pc = att > 0 ? pct : 0.0;
    final pc2 = att > 30
        ? AppColors.green
        : att > 20
            ? AppColors.gold
            : AppColors.red;

    return [
      _label('60-SECOND RESULTS'),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: _box(),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _bigStat('$made', 'MADE', AppColors.green),
              _vDiv(),
              _bigStat('$att', 'SHOTS', AppColors.text1),
              _vDiv(),
              _bigStat(
                  '${(pc * 100).round()}%',
                  'ACC',
                  pc >= 0.70
                      ? AppColors.green
                      : pc >= 0.50
                          ? AppColors.gold
                          : AppColors.red),
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
                            valueColor: AlwaysStoppedAnimation(pc2),
                            minHeight: 6)),
                  ])),
              const SizedBox(width: 16),
              Text('$att / 60s',
                  style: AppText.ui(14, weight: FontWeight.w700, color: pc2)),
            ]),
          ])),
      const SizedBox(height: 14),
      _twoStatCompare('Your shots', '$att shots', 'Target', '30+ shots',
          const Color(0xFFFF7A5C)),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STREAK MODE
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
                      color: AppColors.red.withValues(alpha: 0.12),
                      border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.25))),
                  child: const Icon(Icons.local_fire_department_rounded,
                      color: AppColors.red, size: 28)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Best Streak',
                    style: AppText.ui(12, color: AppColors.text2)),
                Text('$best', style: AppText.display(52, color: AppColors.red)),
                Text('consecutive makes',
                    style: AppText.ui(11, color: AppColors.text3)),
              ]),
            ]),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.borderSub),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _bigStat('$made', 'MADE', AppColors.green),
              _vDiv(),
              _bigStat('$total', 'SHOTS', AppColors.text1),
              _vDiv(),
              _bigStat(
                  '${(pct * 100).round()}%',
                  'ACC',
                  pct >= 0.70
                      ? AppColors.green
                      : pct >= 0.50
                          ? AppColors.gold
                          : AppColors.red),
            ]),
            if (best >= 10) ...[
              const SizedBox(height: 14),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.20))),
                  child: Row(children: [
                    const Text('⭐ ', style: TextStyle(fontSize: 14)),
                    Expanded(
                        child: Text('$best+ streak — elite consistency!',
                            style: AppText.ui(12, color: AppColors.gold)))
                  ])),
            ],
          ])),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PRESSURE FREE THROWS
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
        _completedBanner('All 5 Levels Cleared! 🏆', AppColors.green),
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
                                  ? AppColors.blue.withValues(alpha: 0.12)
                                  : AppColors.bg,
                              border: Border.all(
                                  color: d
                                      ? AppColors.blue.withValues(alpha: 0.35)
                                      : AppColors.border),
                              borderRadius: BorderRadius.circular(10)),
                          child: Center(
                              child: d
                                  ? const Icon(Icons.check_rounded,
                                      size: 18, color: AppColors.blue)
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
                    valueColor: const AlwaysStoppedAnimation(AppColors.blue),
                    minHeight: 6)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _bigStat('$levels/$total', 'LEVELS', AppColors.blue),
              _vDiv(),
              _bigStat('$made', 'MADE', AppColors.green),
              _vDiv(),
              _bigStat(
                  '${(pct * 100).round()}%',
                  'ACC',
                  pct >= 0.70
                      ? AppColors.green
                      : pct >= 0.50
                          ? AppColors.gold
                          : AppColors.red),
            ]),
          ])),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HOT SPOT
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
      _label('SPOT PERFORMANCE'),
      Container(
          padding: const EdgeInsets.all(16),
          decoration: _box(),
          child: Column(
            children: spots.asMap().entries.map((en) {
              final spotMade =
                  (made / 5 * (0.6 + en.key * 0.09)).round().clamp(0, 10);
              final sp = spotMade / 10.0;
              final sc = sp >= 0.7
                  ? AppColors.green
                  : sp >= 0.5
                      ? AppColors.gold
                      : AppColors.red;
              return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sc.withValues(alpha: 0.12),
                            border:
                                Border.all(color: sc.withValues(alpha: 0.30))),
                        child: Center(
                            child: Text('${en.key + 1}',
                                style: AppText.ui(11,
                                    weight: FontWeight.w700, color: sc)))),
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
                                        weight: FontWeight.w700, color: sc)),
                              ]),
                          const SizedBox(height: 5),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                  value: sp,
                                  backgroundColor: AppColors.borderSub,
                                  valueColor: AlwaysStoppedAnimation(sc),
                                  minHeight: 5)),
                        ])),
                  ]));
            }).toList(),
          )),
      const SizedBox(height: 14),
      _twoStatCompare('Total made', '$made', 'Total shots', '$att', e.color),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  AROUND THE WORLD
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
        _completedBanner('Around the World Complete! 🌍', AppColors.green),
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
                                ? AppColors.green.withValues(alpha: 0.14)
                                : AppColors.borderSub.withValues(alpha: 0.5),
                            border: Border.all(
                                color: d
                                    ? AppColors.green.withValues(alpha: 0.45)
                                    : AppColors.border)),
                        child: Center(
                            child: d
                                ? const Icon(Icons.check_rounded,
                                    size: 16, color: AppColors.green)
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
                    valueColor: const AlwaysStoppedAnimation(AppColors.green),
                    minHeight: 7)),
            const SizedBox(height: 8),
            Text('$cleared of $total spots completed',
                style: AppText.ui(12, color: AppColors.text3)),
          ])),
      const SizedBox(height: 14),
      _twoStatCompare('Makes', '$made', 'Attempts', '$att', AppColors.green),
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
              _bigStat('$made', 'MAKES', AppColors.green),
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
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: _box(),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _bigStat('${e.made}', 'MADE', AppColors.green),
          _vDiv(),
          _bigStat('${e.attempts}', 'ATTEMPTS', AppColors.text1),
          _vDiv(),
          _bigStat(e.pctStr, 'ACC', pctColor),
        ]));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ACCURACY PROGRESSION (shot log → running average line)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _accuracyProgression() {
    final log = e.shotLog!;
    final points = <double>[];
    int m = 0;
    for (int i = 0; i < log.length; i++) {
      if (log[i]) m++;
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
  // ══════════════════════════════════════════════════════════════════════════

  Widget _shotLogSection() {
    final log = e.shotLog!;
    final made = log.where((b) => b).length;
    final missed = log.length - made;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('SHOT LOG · ${log.length} shots'),
      Container(
          padding: const EdgeInsets.all(18),
          decoration: _box(),
          child: Column(children: [
            Wrap(
                spacing: 5,
                runSpacing: 5,
                children: log
                    .take(60)
                    .map((m) => Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: m
                                ? AppColors.green
                                : AppColors.red.withValues(alpha: 0.45))))
                    .toList()),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.green)),
              const SizedBox(width: 6),
              Text('$made made', style: AppText.ui(11, color: AppColors.text2)),
              const SizedBox(width: 16),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.red.withValues(alpha: 0.45))),
              const SizedBox(width: 6),
              Text('$missed missed',
                  style: AppText.ui(11, color: AppColors.text2)),
            ]),
          ])),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Text(t,
              style: AppText.ui(9,
                  color: AppColors.text3,
                  letterSpacing: 1.6,
                  weight: FontWeight.w700)),
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
        Icon(icon, size: 11, color: AppColors.text3),
        const SizedBox(width: 5),
        Text(label, style: AppText.ui(11, color: AppColors.text2))
      ]));

  Widget _bigStat(String v, String l, Color c) => Column(children: [
        Text(v, style: AppText.ui(22, weight: FontWeight.w800, color: c)),
        Text(l,
            style: AppText.ui(9, color: AppColors.text3, letterSpacing: 1.0)),
      ]);

  Widget _vDiv() => Container(width: 1, height: 36, color: AppColors.borderSub);

  Widget _accBar(String label, double pct, Color color) => Row(children: [
        SizedBox(
            width: 64,
            child: Text(label,
                style: AppText.ui(11, color: AppColors.text2),
                overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 10),
        Expanded(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.borderSub,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 8))),
        const SizedBox(width: 10),
        Text('${(pct * 100).round()}%',
            style: AppText.ui(12, weight: FontWeight.w700, color: color)),
      ]);

  Widget _infoRow(IconData icon, String label, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: _box(),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.text3),
        const SizedBox(width: 10),
        Text(label, style: AppText.ui(13, color: AppColors.text2)),
        const Spacer(),
        Flexible(
            child: Text(value,
                style: AppText.ui(13, weight: FontWeight.w600),
                overflow: TextOverflow.ellipsis))
      ]));

  Widget _twoStatCompare(
          String l1, String v1, String l2, String v2, Color color) =>
      Container(
          padding: const EdgeInsets.all(16),
          decoration: _box(),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(l1, style: AppText.ui(10, color: AppColors.text3)),
                  const SizedBox(height: 4),
                  Text(v1,
                      style:
                          AppText.ui(18, weight: FontWeight.w800, color: color))
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
                  Text(l2, style: AppText.ui(10, color: AppColors.text3)),
                  const SizedBox(height: 4),
                  Text(v2,
                      style: AppText.ui(18,
                          weight: FontWeight.w800, color: AppColors.text2))
                ])),
          ]));

  Widget _completedBanner(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.military_tech_rounded, color: color, size: 18),
        const SizedBox(width: 8),
        Text(text, style: AppText.ui(13, weight: FontWeight.w700, color: color))
      ]));

  String _timeStr(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Line chart painter ────────────────────────────────────────────────────────

class _LinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  const _LinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final n = points.length;
    final dx = size.width / (n - 1);
    final path = Path();
    final fill = Path();

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

    // avg reference line
    final avg = points.reduce((a, b) => a + b) / n;
    canvas.drawLine(
        Offset(0, size.height * (1 - avg)),
        Offset(size.width, size.height * (1 - avg)),
        Paint()
          ..color = AppColors.text3.withValues(alpha: 0.15)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke);

    // fill
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0)
              ]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // glow + line
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.22)
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

    // last dot
    final lx = (n - 1) * dx, ly = size.height * (1 - points.last);
    canvas.drawCircle(Offset(lx, ly), 5, Paint()..color = color);
    canvas.drawCircle(
        Offset(lx, ly),
        5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_) => false;
}
