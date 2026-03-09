import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/session_service.dart';
import '../models/session.dart';
import 'history_screen.dart';
import 'session_detail_screen.dart';
import 'manual_session_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Data model classes (used by painters / widgets)
// ─────────────────────────────────────────────────────────────────────────────

class _ZoneStat {
  final String label;
  final double pct;
  final int made, attempts, tier;
  const _ZoneStat(this.label, this.pct, this.made, this.attempts, this.tier);
}

class _PosStat {
  final String label;
  final double pct;
  final int attempts;
  const _PosStat(this.label, this.pct, this.attempts);
}

class _SessionStat {
  final Session session;
  final String timeAgo;
  final HoopSession hoopSession;

  _SessionStat(this.session, this.timeAgo)
      : hoopSession = HistoryEntry.fromSession(session).hoopSession!;

  String? get id => session.id;
  String get type => session.type;
  String get zone => session.selectionLabel;
  int get made => session.made;
  int get attempts => session.attempts;
  double get pct => attempts > 0 ? made / attempts : 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stats Screen
// ─────────────────────────────────────────────────────────────────────────────

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))
    ..forward();

  int _chartPeriod = 0; // 0 = week, 1 = month

  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = SessionService().getStatsData();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _entry, curve: Curves.easeOut),
        child: SafeArea(
          child: Column(children: [
            _topBar(),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.text3, size: 48),
                          const SizedBox(height: 16),
                          Text(
                              snapshot.hasError
                                  ? 'Failed to load stats'
                                  : 'No data available',
                              style: AppText.ui(14, color: AppColors.text3)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => setState(() {
                              _statsFuture = SessionService().getStatsData();
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Retry',
                                  style: AppText.ui(13,
                                      weight: FontWeight.w600,
                                      color: AppColors.gold)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final d = snapshot.data!;
                  return _buildContent(d);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> d) {
    // Parse data
    final int totalMade = d['totalMade'] as int;
    final int totalAttempts = d['totalAttempts'] as int;
    final double overallPct = d['overallPct'] as double;
    final int totalSessions = d['totalSessions'] as int;
    final int avgShotsPerSession = d['avgShotsPerSession'] as int;
    final int bestStreak = d['bestStreak'] as int;
    final int currentStreak = d['currentStreak'] as int;
    final int bestSessionPct = d['bestSessionPct'] as int;
    final double consistencyScore = d['consistencyScore'] as double;
    final double weekChange = d['weekChange'] as double;
    final List<double> weekPct = List<double>.from(d['weekPct'] as List);
    final List<String> weekLabels = List<String>.from(d['weekLabels'] as List);
    final List<double> monthPct = List<double>.from(d['monthPct'] as List);
    final List<String> monthLabels =
        List<String>.from(d['monthLabels'] as List);
    final List<List<double>> calendarData = (d['calendarData'] as List)
        .map((row) => List<double>.from(row as List))
        .toList();

    final zones = (d['zones'] as List).map((z) {
      final m = z as Map<String, dynamic>;
      return _ZoneStat(m['label'] as String, (m['pct'] as num).toDouble(),
          m['made'] as int, m['attempts'] as int, m['tier'] as int);
    }).toList();

    final positions = (d['positions'] as List).map((p) {
      final m = p as Map<String, dynamic>;
      return _PosStat(m['label'] as String, (m['pct'] as num).toDouble(),
          m['attempts'] as int);
    }).toList();

    final recentSessions = (d['recentSessions'] as List).map((s) {
      final m = s as Map<String, dynamic>;
      return _SessionStat(
          Session.fromJson(m['session']), m['timeAgo'] as String);
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _heroCard(overallPct, totalMade, totalAttempts, totalSessions,
              avgShotsPerSession, weekChange),
          const SizedBox(height: 10),
          _recordsRow(currentStreak, bestStreak, bestSessionPct),
          const SizedBox(height: 28),
          _sectionLabel('TREND', context),
          const SizedBox(height: 14),
          _trendChart(weekPct, weekLabels, monthPct, monthLabels),
          if (zones.isNotEmpty) ...[
            const SizedBox(height: 28),
            _sectionLabel('SHOT DISTRIBUTION', context),
            const SizedBox(height: 14),
            _shotDistribution(zones),
            const SizedBox(height: 28),
            _sectionLabel('ZONE BREAKDOWN', context),
            const SizedBox(height: 14),
            _zoneBreakdown(zones),
          ],
          if (positions.isNotEmpty) ...[
            const SizedBox(height: 28),
            _sectionLabel('POSITION MAP', context),
            const SizedBox(height: 14),
            _positionMap(positions),
          ],
          const SizedBox(height: 28),
          _sectionLabel('CONSISTENCY CALENDAR', context),
          const SizedBox(height: 14),
          _calendarHeatmap(calendarData, consistencyScore),
          if (recentSessions.isNotEmpty) ...[
            const SizedBox(height: 28),
            _sectionLabel('RECENT SESSIONS', context),
            const SizedBox(height: 14),
            _recentSessions(recentSessions),
          ],
        ],
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────────

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('STATISTICS',
              style: AppText.ui(10,
                  color: AppColors.text3,
                  letterSpacing: 1.8,
                  weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Your performance',
              style: AppText.ui(24, weight: FontWeight.w800)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 13, color: AppColors.text2),
            const SizedBox(width: 6),
            Text('All time',
                style: AppText.ui(12,
                    color: AppColors.text2, weight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(label,
          style: AppText.ui(10,
              color: AppColors.text3,
              letterSpacing: 1.8,
              weight: FontWeight.w700)),
    );
  }

  // ── Hero card ─────────────────────────────────────────────────────────────────

  Widget _heroCard(double pct, int totalMade, int totalAttempts,
      int totalSessions, int avgShotsPerSession, double weekChange) {
    final grade = _grade(pct);
    final gradeColor = _gradeColor(pct);
    final changeStr = weekChange >= 0
        ? '↑ ${weekChange.abs().toStringAsFixed(1)}% this week'
        : '↓ ${weekChange.abs().toStringAsFixed(1)}% this week';
    final changeColor = weekChange >= 0 ? AppColors.green : AppColors.red;
    final changeBgColor = weekChange >= 0
        ? AppColors.greenSoft
        : AppColors.red.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Big % number
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OVERALL SHOOTING',
                        style: AppText.ui(10,
                            color: AppColors.text3,
                            letterSpacing: 1.5,
                            weight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${(pct * 100).round()}',
                          style: AppText.display(80, color: AppColors.text1)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 2),
                        child: Text('%',
                            style: AppText.display(32, color: AppColors.gold)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: changeBgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(changeStr,
                            style: AppText.ui(11,
                                weight: FontWeight.w700, color: changeColor)),
                      ),
                    ]),
                  ]),
            ),
            // Grade ring
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(
                    size: const Size(90, 90),
                    painter: _RingPainter(pct, AppColors.gold)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(grade, style: AppText.display(34, color: gradeColor)),
                  Text('GRADE',
                      style: AppText.ui(8,
                          color: AppColors.text3, letterSpacing: 1.2)),
                ]),
              ]),
            ),
          ]),

          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.borderSub),
          const SizedBox(height: 18),

          // Totals row
          Row(children: [
            _HeroStat('MADE', '$totalMade', AppColors.green),
            _VDiv(),
            _HeroStat('ATTEMPTS', '$totalAttempts', AppColors.text1),
            _VDiv(),
            _HeroStat('SESSIONS', '$totalSessions', AppColors.gold),
            _VDiv(),
            _HeroStat('AVG/SESSION', '$avgShotsPerSession', AppColors.blue),
          ]),
        ]),
      ),
    );
  }

  // ── Records row ───────────────────────────────────────────────────────────────

  Widget _recordsRow(int currentStreak, int bestStreak, int bestSessionPct) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Expanded(
            child: _RecordCard(
          icon: '🔥',
          label: 'CURRENT STREAK',
          value: '$currentStreak',
          sub: 'days in a row',
          color: AppColors.gold,
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _RecordCard(
          icon: '⭐',
          label: 'BEST STREAK',
          value: '$bestStreak',
          sub: 'shots record',
          color: AppColors.blue,
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _RecordCard(
          icon: '🏆',
          label: 'BEST SESSION',
          value: '$bestSessionPct%',
          sub: 'personal best',
          color: AppColors.green,
        )),
      ]),
    );
  }

  // ── Trend chart ───────────────────────────────────────────────────────────────

  Widget _trendChart(List<double> weekPct, List<String> weekLabels,
      List<double> monthPct, List<String> monthLabels) {
    final data = _chartPeriod == 0 ? weekPct : monthPct;
    final labels = _chartPeriod == 0 ? weekLabels : monthLabels;

    // Handle empty/zero data gracefully
    final hasData = data.any((v) => v > 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(children: [
          // Period toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(children: [
              Text('Shooting %',
                  style: AppText.ui(14, weight: FontWeight.w600)),
              const Spacer(),
              Container(
                height: 30,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  _PeriodBtn('7D', _chartPeriod == 0,
                      () => setState(() => _chartPeriod = 0)),
                  _PeriodBtn('6M', _chartPeriod == 1,
                      () => setState(() => _chartPeriod = 1)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          if (hasData) ...[
            // Min/max labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Text(
                    '${(data.where((v) => v > 0).reduce(math.min) * 100).round()}% low',
                    style: AppText.ui(11, color: AppColors.text3)),
                const Spacer(),
                Text('${(data.reduce(math.max) * 100).round()}% peak',
                    style: AppText.ui(11, color: AppColors.green)),
              ]),
            ),
            const SizedBox(height: 4),
            // Chart
            SizedBox(
              height: 160,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: CustomPaint(
                  painter: _LineChartPainter(data: data, labels: labels),
                  size: Size.infinite,
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('No shooting data for this period',
                    style: AppText.ui(13, color: AppColors.text3)),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Shot distribution donut ───────────────────────────────────────────────────

  Widget _shotDistribution(List<_ZoneStat> zones) {
    final total = zones.fold<int>(0, (s, z) => s + z.attempts);
    final colors = [
      AppColors.green,
      AppColors.blue,
      AppColors.gold,
      const Color(0xFFFF7A5C)
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          // Donut
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _DonutChartPainter(
                values: zones.map((z) => z.attempts / total).toList(),
                colors: colors.sublist(0, zones.length),
              ),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$total',
                      style: AppText.display(26, color: AppColors.text1)),
                  Text('shots', style: AppText.ui(10, color: AppColors.text3)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(zones.length, (i) {
                final z = zones[i];
                final share = (z.attempts / total * 100).round();
                final c = i < colors.length ? colors[i] : AppColors.text2;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration:
                            BoxDecoration(shape: BoxShape.circle, color: c)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(z.label,
                            style: AppText.ui(12, weight: FontWeight.w500))),
                    Text('$share%',
                        style:
                            AppText.ui(12, weight: FontWeight.w700, color: c)),
                  ]),
                );
              }),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Zone breakdown ────────────────────────────────────────────────────────────

  Widget _zoneBreakdown(List<_ZoneStat> zones) {
    final maxPct = zones.map((z) => z.pct).reduce(math.max);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children:
              zones.map((z) => _ZoneRow(zone: z, maxPct: maxPct)).toList(),
        ),
      ),
    );
  }

  // ── Position map ──────────────────────────────────────────────────────────────

  Widget _positionMap(List<_PosStat> positions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 340,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CustomPaint(
            painter: _PositionMapPainter(positions),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }

  // ── Consistency calendar ──────────────────────────────────────────────────────

  Widget _calendarHeatmap(
      List<List<double>> calendarData, double consistencyScore) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                  '${calendarData.expand((r) => r).where((v) => v > 0).length} sessions in 5 weeks',
                  style: AppText.ui(13, weight: FontWeight.w600)),
              const Spacer(),
              _consistencyBadge(consistencyScore),
            ]),
            const SizedBox(height: 16),
            // Day labels
            Row(children: [
              const SizedBox(width: 8),
              ...['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => Expanded(
                    child: Center(
                        child: Text(d,
                            style: AppText.ui(10,
                                color: AppColors.text3,
                                weight: FontWeight.w600))),
                  )),
            ]),
            const SizedBox(height: 8),
            // Grid
            ...calendarData.map((week) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const SizedBox(width: 8),
                    ...week.map((val) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: val == 0
                                      ? AppColors.borderSub
                                      : AppColors.gold
                                          .withValues(alpha: 0.15 + 0.75 * val),
                                ),
                              ),
                            ),
                          ),
                        )),
                  ]),
                )),
            const SizedBox(height: 12),
            // Legend
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('Less ', style: AppText.ui(10, color: AppColors.text3)),
              ...List.generate(
                  5,
                  (i) => Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(left: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i == 0
                              ? AppColors.borderSub
                              : AppColors.gold
                                  .withValues(alpha: 0.15 + 0.75 * (i / 4)),
                        ),
                      )),
              Text(' More', style: AppText.ui(10, color: AppColors.text3)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _consistencyBadge(double score) {
    final scoreInt = (score * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Text('Consistency: ', style: AppText.ui(11, color: AppColors.text2)),
        Text('$scoreInt%',
            style: AppText.ui(11,
                weight: FontWeight.w700, color: AppColors.green)),
      ]),
    );
  }

  // ── Recent sessions ───────────────────────────────────────────────────────────

  Widget _recentSessions(List<_SessionStat> sessions) {
    return Column(
      children: sessions.map((s) {
        final pctInt = (s.pct * 100).round();
        final color = s.pct >= 0.70
            ? AppColors.green
            : s.pct >= 0.50
                ? AppColors.gold
                : AppColors.red;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: GestureDetector(
            onTap: () {
              if (s.id == null) return;
              if (s.type == 'manual') {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      ManualSessionDetailScreen(session: s.hoopSession),
                ));
              } else {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _LiveWrapper(session: s.hoopSession),
                ));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Container(
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.zone,
                            style: AppText.ui(14, weight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(s.timeAgo,
                            style: AppText.ui(12, color: AppColors.text3)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: s.pct,
                            backgroundColor: AppColors.borderSub,
                            valueColor: AlwaysStoppedAnimation(color),
                            minHeight: 2,
                          ),
                        ),
                      ]),
                ),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$pctInt%',
                      style: AppText.ui(18,
                          weight: FontWeight.w700, color: color)),
                  Text('${s.made}/${s.attempts}',
                      style: AppText.ui(11, color: AppColors.text3)),
                ]),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Helpers
  String _grade(double pct) {
    if (pct >= 0.85) return 'S';
    if (pct >= 0.75) return 'A';
    if (pct >= 0.65) return 'B';
    if (pct >= 0.50) return 'C';
    return 'D';
  }

  Color _gradeColor(double pct) {
    if (pct >= 0.75) return AppColors.green;
    if (pct >= 0.50) return AppColors.gold;
    return AppColors.red;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HeroStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _HeroStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: AppText.ui(17, weight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: AppText.ui(8, color: AppColors.text3, letterSpacing: 0.8)),
      ]),
    );
  }
}

class _VDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: AppColors.borderSub);
}

class _RecordCard extends StatelessWidget {
  final String icon, label, value, sub;
  final Color color;
  const _RecordCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.sub,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        Text(label,
            style: AppText.ui(9,
                color: AppColors.text3,
                letterSpacing: 1.2,
                weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: AppText.display(26, color: color)),
        Text(sub, style: AppText.ui(10, color: AppColors.text3)),
      ]),
    );
  }
}

class _PeriodBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PeriodBtn(this.label, this.active, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label,
            style: AppText.ui(11,
                weight: FontWeight.w700,
                color: active ? AppColors.bg : AppColors.text3)),
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final _ZoneStat zone;
  final double maxPct;
  const _ZoneRow({required this.zone, required this.maxPct});

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.green,
      AppColors.blue,
      AppColors.gold,
      const Color(0xFFFF7A5C)
    ];
    final color = colors[zone.tier];
    final pctInt = (zone.pct * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(children: [
        Row(children: [
          SizedBox(
            width: 100,
            child: Text(zone.label,
                style: AppText.ui(13, weight: FontWeight.w600)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(height: 8, color: AppColors.borderSub),
                FractionallySizedBox(
                  widthFactor: zone.pct / maxPct,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.6), color]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 42,
            child: Text('$pctInt%',
                style: AppText.ui(13, weight: FontWeight.w700, color: color),
                textAlign: TextAlign.right),
          ),
        ]),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.only(left: 100),
          child: Row(children: [
            Text('${zone.made}/${zone.attempts} shots',
                style: AppText.ui(11, color: AppColors.text3)),
            const Spacer(),
            // Hot/Cold badge
            if (zone.pct >= 0.75)
              const _Badge('🔥 Hot zone', AppColors.green)
            else if (zone.pct < 0.50)
              const _Badge('❄️ Cold zone', AppColors.blue),
          ]),
        ),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: AppText.ui(10, color: color, weight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Painters
// ─────────────────────────────────────────────────────────────────────────────

// ── Ring chart ────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  const _RingPainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    const sw = 6.0;
    const startAngle = -math.pi / 2;

    // Track
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = AppColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw);

    // Progress with gradient sweep
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      startAngle,
      2 * math.pi * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Line chart ────────────────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  const _LineChartPainter({required this.data, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const padLeft = 32.0;
    const padBottom = 24.0;
    const padTop = 12.0;
    final chartW = size.width - padLeft;
    final chartH = size.height - padBottom - padTop;

    final minV = (data.reduce(math.min) - 0.05).clamp(0.0, 1.0);
    final maxV = (data.reduce(math.max) + 0.05).clamp(0.0, 1.0);
    final range = maxV - minV;

    double dx(int i) => padLeft + i * chartW / (data.length - 1);
    double dy(double v) => padTop + (1 - (v - minV) / range) * chartH;

    // Horizontal guides
    final guidePaint = Paint()
      ..color = AppColors.borderSub
      ..strokeWidth = 1;
    for (int g = 0; g <= 4; g++) {
      final y = padTop + g * chartH / 4;
      canvas.drawLine(Offset(padLeft, y), Offset(size.width, y), guidePaint);
      final val = (maxV - g * range / 4) * 100;
      final tp = TextPainter(
        text: TextSpan(
            text: '${val.round()}',
            style: const TextStyle(color: AppColors.text3, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // Gradient area under curve
    final areaPath = Path();
    areaPath.moveTo(dx(0), dy(data[0]));
    for (int i = 1; i < data.length; i++) {
      final cp1 = Offset((dx(i - 1) + dx(i)) / 2, dy(data[i - 1]));
      final cp2 = Offset((dx(i - 1) + dx(i)) / 2, dy(data[i]));
      areaPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, dx(i), dy(data[i]));
    }
    areaPath.lineTo(dx(data.length - 1), padTop + chartH);
    areaPath.lineTo(dx(0), padTop + chartH);
    areaPath.close();

    canvas.drawPath(
        areaPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.gold.withValues(alpha: 0.22),
              AppColors.gold.withValues(alpha: 0.0)
            ],
          ).createShader(Rect.fromLTWH(0, padTop, size.width, chartH)));

    // Line
    final linePath = Path();
    linePath.moveTo(dx(0), dy(data[0]));
    for (int i = 1; i < data.length; i++) {
      final cp1 = Offset((dx(i - 1) + dx(i)) / 2, dy(data[i - 1]));
      final cp2 = Offset((dx(i - 1) + dx(i)) / 2, dy(data[i]));
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, dx(i), dy(data[i]));
    }
    canvas.drawPath(
        linePath,
        Paint()
          ..color = AppColors.gold
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true);

    // Dots + values
    for (int i = 0; i < data.length; i++) {
      final isLast = i == data.length - 1;
      // Dot
      canvas.drawCircle(
          Offset(dx(i), dy(data[i])),
          isLast ? 5 : 3.5,
          Paint()
            ..color = isLast
                ? AppColors.gold
                : AppColors.gold.withValues(alpha: 0.6));
      if (isLast) {
        canvas.drawCircle(
            Offset(dx(i), dy(data[i])),
            5,
            Paint()
              ..color = AppColors.bg
              ..style = PaintingStyle.fill);
        canvas.drawCircle(
            Offset(dx(i), dy(data[i])),
            5,
            Paint()
              ..color = AppColors.gold
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }

      // Label under dot
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: isLast ? AppColors.gold : AppColors.text3,
            fontSize: 10,
            fontWeight: isLast ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(dx(i) - tp.width / 2, size.height - padBottom + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => old.data != data;
}

// ── Donut chart ───────────────────────────────────────────────────────────────

class _DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  const _DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    const gap = 0.025; // gap in radians between segments
    double start = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweep = values[i] * 2 * math.pi - gap;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 8),
        start + gap / 2,
        sweep,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.butt
          ..isAntiAlias = true,
      );
      start += sweep + gap;
    }

    // Inner background circle
    canvas.drawCircle(c, r - 24, Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Position map painter ──────────────────────────────────────────────────────

class _PositionMapPainter extends CustomPainter {
  final List<_PosStat> positions;
  const _PositionMapPainter(this.positions);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bx = w / 2;
    final baseY = h - 16.0;
    final by = baseY - w * 0.105;
    final keyL = bx - w * 0.163;
    final keyR = bx + w * 0.163;
    final ftY = baseY - w * 0.387;
    final ftR = w * 0.120;
    final tpL = bx - w * 0.44;
    final tpR = bx + w * 0.44;
    final tpR_ = w * 0.45;
    final raR = w * 0.083;

    // Court bg
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF161618));

    final lp = Paint()
      ..color = const Color(0xFF353540)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Baseline, sidelines, top
    canvas.drawLine(Offset(0, baseY), Offset(w, baseY), lp);
    canvas.drawLine(const Offset(1, 0), Offset(1, baseY), lp);
    canvas.drawLine(Offset(w - 1, 0), Offset(w - 1, baseY), lp);
    canvas.drawLine(const Offset(0, 1), Offset(w, 1), lp);

    // 3pt arc
    final cosL = (tpL - bx) / tpR_;
    final tpAngle = -math.acos(cosL.clamp(-1.0, 1.0));
    final tpSweep = -2.0 * tpAngle;
    final tpIY = by + tpR_ * math.sin(tpAngle);
    canvas.drawArc(Rect.fromCircle(center: Offset(bx, by), radius: tpR_),
        tpAngle, tpSweep, false, lp);
    canvas.drawLine(Offset(tpL, tpIY), Offset(tpL, baseY), lp);
    canvas.drawLine(Offset(tpR, tpIY), Offset(tpR, baseY), lp);

    // Key
    canvas.drawRect(Rect.fromLTRB(keyL, ftY, keyR, baseY), lp);

    // FT circle
    canvas.drawArc(Rect.fromCircle(center: Offset(bx, ftY), radius: ftR),
        math.pi, math.pi, false, lp);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(bx, ftY), radius: ftR),
        0,
        math.pi,
        false,
        Paint()
          ..color = const Color(0xFF353540).withValues(alpha: 0.35)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke);

    // RA arc
    canvas.drawArc(
        Rect.fromCircle(center: Offset(bx, by), radius: raR),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = const Color(0xFF353540).withValues(alpha: 0.35)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke);

    // Rim
    canvas.drawCircle(
        Offset(bx, by),
        w * 0.040,
        Paint()
          ..color = AppColors.gold.withValues(alpha: 0.5)
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke);

    // Backboard
    canvas.drawLine(
        Offset(bx - w * 0.06, by + w * 0.075),
        Offset(bx + w * 0.06, by + w * 0.075),
        Paint()
          ..color = AppColors.text2.withValues(alpha: 0.40)
          ..strokeWidth = 2.0);

    // ── Position dots ──────────────────────────────────────────────────────────
    // Map position labels to fractional coords (mirrors CourtGeo spots)
    final coordMap = <String, Offset>{
      'Free Throw': Offset(bx, ftY),
      'Left Corner': Offset(tpL, baseY - w * 0.05),
      'Right Corner': Offset(tpR, baseY - w * 0.05),
      'Left Wing': Offset(
          bx - 0.38 * w, by - math.sqrt((tpR_ * tpR_) - (0.38 * w * 0.38 * w))),
      'Right Wing': Offset(
          bx + 0.38 * w, by - math.sqrt((tpR_ * tpR_) - (0.38 * w * 0.38 * w))),
      'Top of Arc': Offset(bx, by - tpR_),
      'Left Elbow': Offset(keyL, ftY),
      'Right Elbow': Offset(keyR, ftY),
      'Left Block': Offset(keyL + w * 0.042, by + w * 0.072),
      'Right Block': Offset(keyR - w * 0.042, by + w * 0.072),
      'Left Mid': Offset(keyL - w * 0.12, by - w * 0.13),
      'Right Mid': Offset(keyR + w * 0.12, by - w * 0.13),
    };

    for (final pos in positions) {
      final center = coordMap[pos.label];
      if (center == null) continue;

      final pct = pos.pct;
      final Color dotColor;
      if (pct >= 0.75) {
        dotColor = AppColors.green;
      } else if (pct >= 0.55) {
        dotColor = AppColors.gold;
      } else {
        dotColor = AppColors.red;
      }

      final radius = 7.0 + (pos.attempts / 215.0) * 6.0; // size ∝ volume

      // Glow
      canvas.drawCircle(center, radius + 6,
          Paint()..color = dotColor.withValues(alpha: 0.12));
      // Fill
      canvas.drawCircle(
          center, radius, Paint()..color = dotColor.withValues(alpha: 0.85));
      // Border
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = dotColor
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);

      // % label inside
      final tp = TextPainter(
        text: TextSpan(
          text: '${(pct * 100).round()}',
          style: const TextStyle(
              color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
    }

    // Legend
    _drawLegend(canvas, size);
  }

  void _drawLegend(Canvas canvas, Size size) {
    final items = [
      ('≥75%', AppColors.green),
      ('55–74%', AppColors.gold),
      ('<55%', AppColors.red),
    ];
    double x = 14;
    final y = size.height - 14.0;
    for (final item in items) {
      canvas.drawCircle(Offset(x + 5, y), 5, Paint()..color = item.$2);
      final tp = TextPainter(
        text: TextSpan(
            text: ' ${item.$1}',
            style: const TextStyle(color: AppColors.text3, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 10, y - tp.height / 2));
      x += 10 + tp.width + 12;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Live session wrapper for correct animation ────────────────────────────────
class _LiveWrapper extends StatefulWidget {
  final HoopSession session;
  const _LiveWrapper({required this.session});
  @override
  State<_LiveWrapper> createState() => _LiveWrapperState();
}

class _LiveWrapperState extends State<_LiveWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))
    ..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SessionDetailScreen(session: widget.session, animation: _c);
}
