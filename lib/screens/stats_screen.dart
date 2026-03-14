import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/session_service.dart';
import '../widgets/basketball_court_map.dart';
import '../utils/performance.dart';

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

// Removed _SessionStat

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

  late Future<Map<String, dynamic>> _statsFuture;
  String _activeFilter = 'All time';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  StreamSubscription? _updateSub;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _updateSub = SessionService().updates.listen((_) => setState(() => _loadStats()));
  }

  void _loadStats() {
    _statsFuture = SessionService()
        .getStatsData(startDate: _filterStartDate, endDate: _filterEndDate);
  }

  void _setFilter(String label, {DateTime? start, DateTime? end}) {
    setState(() {
      _activeFilter = label;
      _filterStartDate = start;
      _filterEndDate = end;
      _loadStats();
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.gold,
              onPrimary: AppColors.bg,
              surface: AppColors.surface,
              onSurface: AppColors.text1,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final start = DateTime(date.year, date.month, date.day);
      final end = DateTime(date.year, date.month, date.day, 23, 59, 59);
      _setFilter('${date.day}.${date.month}.${date.year}',
          start: start, end: end);
    }
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _filterItem('Today', () {
                _setFilter('Today', start: today);
                Navigator.pop(context);
              }),
              _filterItem('All time', () {
                _setFilter('All time');
                Navigator.pop(context);
              }),
              _filterItem('Past Week', () {
                _setFilter('Past Week',
                    start: today.subtract(const Duration(days: 7)));
                Navigator.pop(context);
              }),
              _filterItem('Past Month', () {
                _setFilter('Past Month',
                    start: DateTime(now.year, now.month - 1, now.day));
                Navigator.pop(context);
              }),
              _filterItem('Past Year', () {
                _setFilter('Past Year',
                    start: DateTime(now.year - 1, now.month, now.day));
                Navigator.pop(context);
              }),
              _filterItem('Specific Date...', () {
                Navigator.pop(context);
                _pickDate();
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _filterItem(String label, VoidCallback onTap) {
    final active = _activeFilter == label ||
        (label == 'Specific Date...' &&
            !['All time', 'Past Week', 'Past Month', 'Past Year']
                .contains(_activeFilter));

    return ListTile(
      title: Text(label,
          style: AppText.ui(16,
              weight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.gold : AppColors.text1)),
      trailing: active
          ? const Icon(Icons.check, color: AppColors.gold, size: 20)
          : null,
      onTap: onTap,
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    _updateSub?.cancel();
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
                              style: AppText.ui(14, color: AppColors.text2)),
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _heroCard(overallPct, totalMade, totalAttempts, totalSessions,
              avgShotsPerSession),
          const SizedBox(height: 10),
          _recordsRow(currentStreak, bestStreak),
          const SizedBox(height: 28),
          _sectionLabel('SHOT DISTRIBUTION', context),
          const SizedBox(height: 14),
          _shotDistribution(zones),
          const SizedBox(height: 28),
          _sectionLabel('ZONE BREAKDOWN', context),
          const SizedBox(height: 14),
          _zoneBreakdown(zones),
          const SizedBox(height: 28),
          _sectionLabel('POSITION MAP', context),
          const SizedBox(height: 14),
          _positionMap(positions),
          // Recent Sessions removed as redundant with History
        ],
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────────

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('STATISTICS',
              style: AppText.ui(11,
                  color: AppColors.text2,
                  letterSpacing: 1.4,
                  weight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('Your performance',
              style: AppText.ui(24, weight: FontWeight.w800)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: _showFilterMenu,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: AppColors.text2),
              const SizedBox(width: 8),
              Text(_activeFilter,
                  style: AppText.ui(12,
                      color: AppColors.text2, weight: FontWeight.w500)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down,
                  size: 14, color: AppColors.text3),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(label,
          style: AppText.ui(11,
              color: AppColors.text2,
              letterSpacing: 1.4,
              weight: FontWeight.w800)),
    );
  }

  // ── Hero card ─────────────────────────────────────────────────────────────────

  Widget _heroCard(double pct, int totalMade, int totalAttempts,
      int totalSessions, int avgShotsPerSession) {
    final grade = _grade(pct);
    final gradeColor = _gradeColor(pct);
    // weekChange removed
    // final changeStr = weekChange >= 0
    //     ? '↑ ${weekChange.abs().toStringAsFixed(1)}% this week'
    //     : '↓ ${weekChange.abs().toStringAsFixed(1)}% this week';
    // final changeColor = weekChange >= 0 ? AppColors.green : AppColors.red;
    // final changeBgColor = weekChange >= 0
    //     ? AppColors.greenSoft
    //     : AppColors.red.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                        style: AppText.ui(11,
                            color: AppColors.text2,
                            letterSpacing: 1.2,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${(pct * 100).round()}',
                          style: AppText.display(80, color: gradeColor)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 2),
                        child: Text('%',
                            style: AppText.display(32, color: gradeColor)),
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
                    painter: _RingPainter(pct, gradeColor)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(grade, style: AppText.display(34, color: gradeColor)),
                  Text('GRADE',
                      style: AppText.ui(11,
                          color: AppColors.text2,
                          letterSpacing: 0.5,
                          weight: FontWeight.w700)),
                ]),
              ]),
            ),
          ]),

          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.borderSub),
          const SizedBox(height: 18),

          // Totals row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeroStat('MADE', '$totalMade', AppColors.green),
              _VDiv(),
              _HeroStat('ATTEMPTS', '$totalAttempts', AppColors.text1),
              _VDiv(),
              _HeroStat('SESSIONS', '$totalSessions', AppColors.gold),
              _VDiv(),
              _HeroStat('AVG/SESSION', '$avgShotsPerSession', AppColors.blue),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Records row ───────────────────────────────────────────────────────────────

  Widget _recordsRow(int currentStreak, int bestStreak) {
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
        const SizedBox(width: 12),
        Expanded(
            child: _RecordCard(
          icon: '⭐',
          label: 'BEST STREAK',
          value: '$bestStreak',
          sub: 'shots record',
          color: AppColors.blue,
        )),
      ]),
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
                values: total > 0
                    ? zones.map((z) => z.attempts / total).toList()
                    : [1.0],
                colors: total > 0
                    ? colors.sublist(0, zones.length)
                    : [AppColors.borderSub],
              ),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$total',
                      style: AppText.display(26, color: AppColors.text1)),
                  Text('shots', style: AppText.ui(12, color: AppColors.text2)),
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
                final share =
                    total > 0 ? (z.attempts / total * 100).round() : 0;
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
              zones.map((z) => _ZoneRow(zone: z)).toList(),
        ),
      ),
    );
  }

  // ── Position map ──────────────────────────────────────────────────────────────

  Widget _positionMap(List<_PosStat> positions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: BasketballCourtMap(
          themeColor: AppColors.gold,
          mode: CourtMapMode.stats,
          showLegend: true,
          spots: positions
              .map((p) => MapSpotData(
                    id: p.label.toLowerCase().replaceAll(' ', '_'),
                    label: p.label,
                    pct: p.pct,
                    attempts: p.attempts,
                  ))
              .toList(),
        ),
      ),
    );
  }

  // Helpers
  String _grade(double pct) => PerformanceGuide.gradeFor(pct);
  Color _gradeColor(double pct) => PerformanceGuide.colorFor(pct);
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
    return Column(children: [
      Text(value, style: AppText.ui(18, weight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label,
          style: AppText.ui(11,
              color: AppColors.text2,
              letterSpacing: 0.5,
              weight: FontWeight.w700)),
    ]);
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
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(label,
                  style: AppText.ui(10,
                      color: AppColors.text2,
                      letterSpacing: 0.8,
                      weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: AppText.display(36, color: color)),
          const SizedBox(height: 2),
          Text(sub, style: AppText.ui(11, color: AppColors.text3)),
        ],
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final _ZoneStat zone;
  const _ZoneRow({required this.zone});

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
                  widthFactor: zone.pct.clamp(0.0, 1.0),
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
                style: AppText.ui(12, color: AppColors.text2)),
            const Spacer(),
            // Hot/Cold badge
            if (zone.attempts > 0 && zone.pct >= 0.75)
              const _Badge('🔥 Hot zone', AppColors.green)
            else if (zone.attempts > 0 && zone.pct < 0.50)
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
          style: AppText.ui(11, color: color, weight: FontWeight.w600)),
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

    // Count non-zero segments for gap calculation
    final nonZero = values.where((v) => v > 0).length;
    final effectiveGap = nonZero > 1 ? gap : 0.0;

    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = values[i] * 2 * math.pi - effectiveGap;
      if (sweep <= 0) continue;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 8),
        start + effectiveGap / 2,
        sweep,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.butt
          ..isAntiAlias = true,
      );
      start += sweep + effectiveGap;
    }

    // Inner background circle
    canvas.drawCircle(c, r - 24, Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(_) => false;
}
