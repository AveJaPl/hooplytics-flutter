import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'session_setup_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  HOOP SESSION  –  shared model for live + manual sessions
// ═════════════════════════════════════════════════════════════════════════════

class HoopSession {
  final String id;
  final SessionMode mode;
  final String zone;
  final String dateLabel;
  final DateTime date;
  final int made;
  final int attempts;
  final Color color;
  final bool isLive;
  final Duration? elapsed;
  final List<bool>? shotHistory;
  final int? maxStreak;
  final int? swishPct;
  final int globalAvgPct;

  const HoopSession({
    required this.id,
    required this.mode,
    required this.zone,
    required this.dateLabel,
    required this.date,
    required this.made,
    required this.attempts,
    required this.color,
    required this.isLive,
    this.elapsed,
    this.shotHistory,
    this.maxStreak,
    this.swishPct,
    required this.globalAvgPct,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
//  SESSION DETAIL SCREEN  –  for LIVE tracked sessions
// ═════════════════════════════════════════════════════════════════════════════

class SessionDetailScreen extends StatelessWidget {
  final HoopSession session;
  final Animation<double> animation;

  const SessionDetailScreen({
    super.key,
    required this.session,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final String id = session.id;
    final SessionMode mode = session.mode;
    final String zone = session.zone;
    final String dateLabel = session.dateLabel;
    final int made = session.made;
    final int attempts = session.attempts;
    final Color color = session.color;
    final int pct = (made / attempts * 100).round();

    final courtAnim = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(context),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(children: [
                const SizedBox(height: 10),
                _buildHeader(zone, dateLabel, pct, color),
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: courtAnim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.05), end: Offset.zero)
                        .animate(courtAnim),
                    child: _buildCourtDisplay(id, mode),
                  ),
                ),
                const SizedBox(height: 40),
                _buildStatsRow(made, attempts, color),
                if (session.isLive &&
                    (session.shotHistory?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 32),
                  _buildProgressionChart(),
                  const SizedBox(height: 32),
                  _buildLiveSection(),
                ],
                const SizedBox(height: 32),
                _buildPerformanceSection(),
                const SizedBox(height: 32),
                _buildSessionAnalysis(),
                const SizedBox(height: 48),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.text2)),
        ),
        const SizedBox(width: 14),
        Text('SESSION DETAILS',
            style: AppText.ui(12,
                color: AppColors.text3,
                letterSpacing: 1.5,
                weight: FontWeight.w700)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: AppColors.green.withValues(alpha: 0.28))),
          child: Text('LIVE',
              style: AppText.ui(9,
                  weight: FontWeight.w800,
                  color: AppColors.green,
                  letterSpacing: 0.8)),
        ),
      ]),
    );
  }

  Widget _buildHeader(String zone, String dateLabel, int pct, Color color) {
    return Column(children: [
      Text(zone,
          style: AppText.ui(28, weight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 6),
      Text(dateLabel, style: AppText.ui(14, color: AppColors.text3)),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 5)
            ]),
        child: Text('$pct%', style: AppText.display(64, color: color)),
      ),
    ]);
  }

  Widget _buildCourtDisplay(String selectedId, SessionMode mode) {
    return AspectRatio(
      aspectRatio: 1.25,
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            color: const Color(0xFF131315)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LayoutBuilder(builder: (_, box) {
            final geo = CourtGeo(box.maxWidth, box.maxHeight);
            return Stack(children: [
              Positioned.fill(
                  child: CustomPaint(painter: CourtLinePainter(geo))),
              if (mode == SessionMode.range)
                Positioned.fill(
                    child: CustomPaint(
                        painter: RangeZonePainter(geo, selectedId, const [
                  RangeZone('layup', 'Layup', 0),
                  RangeZone('close', 'Close Shot', 1),
                  RangeZone('mid', 'Mid Range', 2),
                  RangeZone('three', 'Three Point', 3),
                ]))),
              if (mode == SessionMode.position)
                ..._buildReadonlySpots(geo, selectedId),
            ]);
          }),
        ),
      ),
    );
  }

  List<Widget> _buildReadonlySpots(CourtGeo geo, String selectedId) {
    if (selectedId.isEmpty) return [];

    return geo.spots.map((spot) {
      if (spot.id != selectedId) return const SizedBox.shrink();
      final px = spot.fx * geo.w;
      final py = spot.fy * geo.h;
      return Positioned(
          left: px - 28,
          top: py - 28,
          child: CourtSpotWidget(selected: true, label: spot.label));
    }).toList();
  }

  Widget _buildStatsRow(int made, int attempts, Color color) {
    return Row(children: [
      _buildStatCard('MADE', made.toString(), color),
      const SizedBox(width: 16),
      _buildStatCard('ATTEMPTS', attempts.toString(), AppColors.text1),
    ]);
  }

  Widget _buildStatCard(String label, String value, Color valueColor) {
    return Expanded(
        child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Text(value, style: AppText.display(36, color: valueColor)),
        const SizedBox(height: 4),
        Text(label,
            style: AppText.ui(11,
                color: AppColors.text3,
                letterSpacing: 1.5,
                weight: FontWeight.w700)),
      ]),
    ));
  }

  Widget _buildLiveSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('SESSION TIMELINE',
            style: AppText.ui(10,
                color: AppColors.text3,
                letterSpacing: 1.5,
                weight: FontWeight.w700)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: AppColors.goldSoft,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3))),
          child: Text('🔥 STREAK: ${session.maxStreak ?? 0}',
              style: AppText.ui(10,
                  weight: FontWeight.w800, color: AppColors.gold)),
        ),
      ]),
      const SizedBox(height: 16),
      Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border)),
          child: _buildTimelineChart()),
    ]);
  }

  Widget _buildTimelineChart() {
    final history = session.shotHistory ?? [];
    if (history.isEmpty) {
      return Center(
          child: Text('No shot data recorded.',
              style: AppText.ui(12, color: AppColors.text3)));
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final make = history[index];
        return Center(
            child: Container(
                width: 14,
                height: make ? 24 : 14,
                decoration: BoxDecoration(
                    color: make ? AppColors.green : AppColors.surfaceHi,
                    borderRadius: BorderRadius.circular(7))));
      },
    );
  }

  Widget _buildProgressionChart() {
    final history = session.shotHistory ?? [];
    List<double> points = [];
    int runningMade = 0;
    for (int i = 0; i < history.length; i++) {
      if (history[i]) runningMade++;
      points.add(runningMade / (i + 1));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('ACCURACY PROGRESSION',
          style: AppText.ui(10,
              color: AppColors.text3,
              letterSpacing: 1.5,
              weight: FontWeight.w700)),
      const SizedBox(height: 16),
      Container(
          height: 160,
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border)),
          child: CustomPaint(
              painter: _AccuracyLinePainter(
                  points: points,
                  color: session.color,
                  avg: history.isEmpty ? 0 : runningMade / history.length))),
    ]);
  }

  Widget _buildPerformanceSection() {
    final swish = session.swishPct != null ? '${session.swishPct}%' : 'N/A';
    final pct = (session.made / session.attempts * 100).round();
    final diff = pct - session.globalAvgPct;
    final diffStr = diff >= 0 ? '+$diff%' : '$diff%';
    final diffColor = diff >= 0 ? AppColors.green : AppColors.red;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PERFORMANCE',
          style: AppText.ui(10,
              color: AppColors.text3,
              letterSpacing: 1.5,
              weight: FontWeight.w700)),
      const SizedBox(height: 16),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border)),
          child: Column(children: [
            _advRow('Swish %', swish, Icons.lens_blur_rounded),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: AppColors.border)),
            Row(children: [
              const Icon(Icons.public_rounded,
                  color: AppColors.text3, size: 20),
              const SizedBox(width: 12),
              Text('vs Global Average',
                  style: AppText.ui(14,
                      color: AppColors.text2, weight: FontWeight.w500)),
              const Spacer(),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: diffColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(diffStr,
                      style: AppText.ui(13,
                          color: diffColor, weight: FontWeight.w700))),
              const SizedBox(width: 8),
              Text('(${session.globalAvgPct}%)',
                  style: AppText.ui(13,
                      color: AppColors.text3, weight: FontWeight.w500)),
            ]),
          ])),
    ]);
  }

  Widget _advRow(String label, String value, IconData icon) => Row(children: [
        Icon(icon, color: AppColors.text3, size: 20),
        const SizedBox(width: 12),
        Text(label,
            style: AppText.ui(14,
                color: AppColors.text2, weight: FontWeight.w500)),
        const Spacer(),
        Text(value,
            style:
                AppText.ui(15, color: Colors.white, weight: FontWeight.w700)),
      ]);

  Widget _buildSessionAnalysis() {
    final history = session.shotHistory ?? [];
    String closerVal = 'N/A';
    if (history.length >= 5) {
      final last =
          history.sublist(history.length - math.min(10, history.length));
      closerVal =
          '${(last.where((s) => s).length / last.length * 100).round()}%';
    }
    int maxMiss = 0, cur = 0;
    for (var m in history) {
      if (!m) {
        cur++;
        if (cur > maxMiss) maxMiss = cur;
      } else {
        cur = 0;
      }
    }
    final stability = maxMiss <= 2
        ? 'ELITE'
        : maxMiss <= 4
            ? 'SOLID'
            : 'VOLATILE';
    String pattern = 'BALANCED';
    if (history.length >= 10) {
      final mid = history.length ~/ 2;
      final f = history.sublist(0, mid).where((s) => s).length / mid;
      final s =
          history.sublist(mid).where((s) => s).length / (history.length - mid);
      if (s > f + 0.15) {
        pattern = 'STRONG FINISH';
      } else if (f > s + 0.15) {
        pattern = 'HOT START';
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SESSION INSIGHTS',
          style: AppText.ui(10,
              color: AppColors.text3,
              letterSpacing: 1.5,
              weight: FontWeight.w700)),
      const SizedBox(height: 16),
      GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _analysisCard(
                'THE CLOSER', closerVal, Icons.bolt_rounded, AppColors.gold),
            _analysisCard('STABILITY', stability, Icons.vibration_rounded,
                AppColors.blue),
            _analysisCard('RECORD RANK', '#3 BEST', Icons.emoji_events_rounded,
                AppColors.green),
            _analysisCard(
                'PATTERN', pattern, Icons.waves_rounded, Colors.purpleAccent),
          ]),
    ]);
  }

  Widget _analysisCard(String label, String value, IconData icon, Color color) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: AppText.ui(9,
                    color: AppColors.text3,
                    weight: FontWeight.w700,
                    letterSpacing: 0.5))
          ]),
          const Spacer(),
          Text(value,
              style:
                  AppText.ui(18, color: Colors.white, weight: FontWeight.w800)),
        ]));
  }
}

// ── Progression Chart Painter ─────────────────────────────────────────────────

class _AccuracyLinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final double avg;
  _AccuracyLinePainter(
      {required this.points, required this.color, required this.avg});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final fillPaint = Paint()
      ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0)
          ]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final path = Path(), fillPath = Path();
    final dx = size.width / (points.length - 1);
    path.moveTo(0, size.height * (1 - points[0]));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, size.height * (1 - points[0]));
    for (int i = 1; i < points.length; i++) {
      final x = i * dx, y = size.height * (1 - points[i]);
      final px = (i - 1) * dx, py = size.height * (1 - points[i - 1]);
      path.quadraticBezierTo(px, py, (px + x) / 2, (py + y) / 2);
      fillPath.quadraticBezierTo(px, py, (px + x) / 2, (py + y) / 2);
      if (i == points.length - 1) {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawLine(
        Offset(0, size.height * (1 - avg)),
        Offset(size.width, size.height * (1 - avg)),
        Paint()
          ..color = AppColors.text3.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => true;
}
