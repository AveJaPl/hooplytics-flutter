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
  final Color color; // session TYPE color — stays constant everywhere
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
//
//  COLOR PHILOSOPHY
//  ─────────────────
//  session.color  → primary accent everywhere (ring, gradient, grade, bars)
//                   Set externally to blue=Live, green=Manual, gold=Game.
//  Performance     → ONLY shown as small secondary delta indicator
//                   (↑/↓ arrow + text). Never overrides session.color.
// ═════════════════════════════════════════════════════════════════════════════

class SessionDetailScreen extends StatelessWidget {
  final HoopSession session;
  final Animation<double> animation;

  const SessionDetailScreen({
    super.key,
    required this.session,
    required this.animation,
  });

  // ── helpers ───────────────────────────────────────────────────────────────

  int get _pct => session.attempts > 0
      ? (session.made / session.attempts * 100).round()
      : 0;

  /// Grade letter — purely textual, rendered in session.color
  String get _grade {
    if (_pct >= 85) return 'S';
    if (_pct >= 75) return 'A';
    if (_pct >= 65) return 'B';
    if (_pct >= 50) return 'C';
    return 'D';
  }

  /// Small delta vs global avg — only place where red/green appear
  int get _delta => _pct - session.globalAvgPct;
  String get _deltaStr => _delta >= 0 ? '+$_delta%' : '$_delta%';
  Color get _deltaColor => _delta >= 0 ? AppColors.green : AppColors.red;
  IconData get _deltaIcon =>
      _delta >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final courtAnim = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _topBar(context),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 60),
              child: Column(children: [
                _heroSection(),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: courtAnim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.05), end: Offset.zero)
                        .animate(courtAnim),
                    child: _courtSection(),
                  ),
                ),
                const SizedBox(height: 24),
                _statsRow(),
                if (session.isLive &&
                    (session.shotHistory?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 24),
                  _progressionChart(),
                  const SizedBox(height: 24),
                  _timelineSection(),
                ],
                const SizedBox(height: 24),
                _performanceSection(),
                const SizedBox(height: 24),
                _insightsSection(),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _topBar(BuildContext context) => Padding(
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
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SESSION DETAILS',
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.8,
                    weight: FontWeight.w700)),
            Text(session.zone, style: AppText.ui(15, weight: FontWeight.w700)),
          ]),
          const Spacer(),
          // Type badge — uses session.color directly
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
                color: session.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
                border:
                    Border.all(color: session.color.withValues(alpha: 0.30))),
            child: Text(session.isLive ? 'LIVE' : 'MANUAL',
                style: AppText.ui(9,
                    weight: FontWeight.w800,
                    color: session.color,
                    letterSpacing: 0.8)),
          ),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  HERO SECTION
  //  Ring + grade both use session.color.
  //  Delta badge is the only place performance color (green/red) appears.
  // ══════════════════════════════════════════════════════════════════════════

  Widget _heroSection() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            session.color.withValues(alpha: 0.16),
            session.color.withValues(alpha: 0.04),
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: session.color.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Left column: text info ──────────────────────────────────────────
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(session.zone,
                    style: AppText.ui(22, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(
                      session.mode == SessionMode.position
                          ? Icons.place_rounded
                          : Icons.crop_square_rounded,
                      size: 12,
                      color: AppColors.text3),
                  const SizedBox(width: 5),
                  Text(
                      session.mode == SessionMode.position
                          ? 'Position'
                          : 'Range',
                      style: AppText.ui(12, color: AppColors.text3)),
                ]),
                const SizedBox(height: 16),
                _chip(Icons.calendar_today_rounded, session.dateLabel),
                const SizedBox(height: 8),
                // Delta badge — the ONLY element using green/red
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _deltaColor.withValues(alpha: 0.08),
                      border: Border.all(
                          color: _deltaColor.withValues(alpha: 0.22)),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_deltaIcon, size: 12, color: _deltaColor),
                    const SizedBox(width: 5),
                    Text('$_deltaStr vs global avg',
                        style: AppText.ui(11,
                            weight: FontWeight.w600, color: _deltaColor)),
                  ]),
                ),
              ])),
          const SizedBox(width: 20),
          // ── Right column: ring + grade ──────────────────────────────────────
          // Both use session.color — no red/gold/green here
          Column(children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: _RingPainter(
                  value: session.attempts > 0
                      ? session.made / session.attempts
                      : 0,
                  trackColor: session.color.withValues(alpha: 0.15),
                  arcColor: session.color,
                ),
                child: Center(
                  child: Text('$_pct%',
                      style: AppText.display(22, color: session.color)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Grade badge — session.color background, grade letter inside
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: session.color.withValues(alpha: 0.12),
                  border:
                      Border.all(color: session.color.withValues(alpha: 0.32))),
              child: Center(
                  child: Text(_grade,
                      style: AppText.display(20, color: session.color))),
            ),
          ]),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  COURT SECTION
  // ══════════════════════════════════════════════════════════════════════════

  Widget _courtSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('COURT POSITION'),
        AspectRatio(
          aspectRatio: 1.3,
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
                  if (session.mode == SessionMode.range)
                    Positioned.fill(
                        child: CustomPaint(
                            painter: RangeZonePainter(geo, session.id, const [
                      RangeZone('layup', 'Layup', 0),
                      RangeZone('close', 'Close Shot', 1),
                      RangeZone('mid', 'Mid Range', 2),
                      RangeZone('three', 'Three Point', 3),
                    ]))),
                  if (session.mode == SessionMode.position)
                    ..._readonlySpots(geo),
                ]);
              }),
            ),
          ),
        ),
      ]);

  List<Widget> _readonlySpots(CourtGeo geo) {
    if (session.id.isEmpty) return [];
    return geo.spots.map((spot) {
      if (spot.id != session.id) return const SizedBox.shrink();
      return Positioned(
          left: spot.fx * geo.w - 28,
          top: spot.fy * geo.h - 28,
          child: CourtSpotWidget(selected: true, label: spot.label));
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STATS ROW
  //  Uses session.color for MADE, neutral for rest — no red
  // ══════════════════════════════════════════════════════════════════════════

  Widget _statsRow() => Row(children: [
        _statCard('MADE', '${session.made}', session.color),
        const SizedBox(width: 12),
        _statCard(
            'MISSED', '${session.attempts - session.made}', AppColors.text2),
        const SizedBox(width: 12),
        _statCard('TOTAL', '${session.attempts}', AppColors.text1),
      ]);

  Widget _statCard(String label, String value, Color valueColor) => Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Text(value, style: AppText.display(30, color: valueColor)),
          const SizedBox(height: 4),
          Text(label,
              style: AppText.ui(9,
                  color: AppColors.text3,
                  letterSpacing: 1.2,
                  weight: FontWeight.w700)),
        ]),
      ));

  // ══════════════════════════════════════════════════════════════════════════
  //  PROGRESSION CHART
  // ══════════════════════════════════════════════════════════════════════════

  Widget _progressionChart() {
    final history = session.shotHistory ?? [];
    final points = <double>[];
    int runningMade = 0;
    for (int i = 0; i < history.length; i++) {
      if (history[i]) runningMade++;
      points.add(runningMade / (i + 1));
    }
    final avg = history.isEmpty ? 0.0 : runningMade / history.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('ACCURACY PROGRESSION'),
      Container(
        height: 150,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: CustomPaint(
            painter: _AccuracyLinePainter(
                points: points, color: session.color, avg: avg)),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TIMELINE  (shot history bar chart)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _timelineSection() {
    final history = session.shotHistory ?? [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('SESSION TIMELINE',
            style: AppText.ui(10,
                color: AppColors.text3,
                letterSpacing: 1.5,
                weight: FontWeight.w700)),
        if ((session.maxStreak ?? 0) > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: session.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: session.color.withValues(alpha: 0.25))),
            child: Text('🔥 STREAK ${session.maxStreak}',
                style: AppText.ui(10,
                    weight: FontWeight.w800, color: session.color)),
          ),
      ]),
      const SizedBox(height: 12),
      Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: history.isEmpty
            ? Center(
                child: Text('No shot data',
                    style: AppText.ui(12, color: AppColors.text3)))
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(width: 5),
                itemBuilder: (_, i) {
                  final make = history[i];
                  return Center(
                      child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 12,
                    // made = session color bar, missed = dim stub
                    height: make ? 30 : 12,
                    decoration: BoxDecoration(
                        color: make
                            ? session.color.withValues(alpha: 0.85)
                            : AppColors.surfaceHi,
                        borderRadius: BorderRadius.circular(6)),
                  ));
                },
              ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PERFORMANCE SECTION
  //  Accuracy bar → session.color
  //  Global avg bar → neutral text3
  //  Delta result → the one place green/red appear (but small & subtle)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _performanceSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('PERFORMANCE'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            // ── Your accuracy (session.color) ──────────────────────────────
            _barRow('Your accuracy', '$_pct%', _pct / 100, session.color),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.borderSub),
            const SizedBox(height: 14),
            // ── Global average (neutral) ───────────────────────────────────
            _barRow('Global average', '${session.globalAvgPct}%',
                session.globalAvgPct / 100, AppColors.text3),
            const SizedBox(height: 16),
            // ── Delta result — only small green/red here ───────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: _deltaColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: _deltaColor.withValues(alpha: 0.16))),
              child: Row(children: [
                Icon(_deltaIcon, size: 15, color: _deltaColor),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  _delta >= 0
                      ? 'Above average by $_delta% — great session!'
                      : 'Below average by ${_delta.abs()}% — keep training!',
                  style: AppText.ui(12, color: _deltaColor),
                )),
              ]),
            ),
          ]),
        ),
      ]);

  Widget _barRow(String label, String valueStr, double value, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: AppText.ui(12, color: AppColors.text2)),
          Text(valueStr,
              style: AppText.ui(13, weight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              backgroundColor: AppColors.borderSub,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 7),
        ),
      ]);

  // ══════════════════════════════════════════════════════════════════════════
  //  INSIGHTS GRID
  //  Each card uses its own semantic icon color for the icon only,
  //  the value text stays white — no red/gold/green dominating cards.
  // ══════════════════════════════════════════════════════════════════════════

  Widget _insightsSection() {
    final history = session.shotHistory ?? [];

    // The Closer
    String closerVal = 'N/A';
    if (history.length >= 5) {
      final last =
          history.sublist(history.length - math.min(10, history.length));
      closerVal =
          '${(last.where((s) => s).length / last.length * 100).round()}%';
    }

    // Stability
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

    // Pattern
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
      _label('SESSION INSIGHTS'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.5,
        children: [
          // Icon uses session.color for brand consistency, value is white
          _insightCard(
              'THE CLOSER', closerVal, Icons.bolt_rounded, session.color),
          _insightCard(
              'STABILITY', stability, Icons.vibration_rounded, AppColors.text2),
          _insightCard('MAX STREAK', '${session.maxStreak ?? 0}',
              Icons.local_fire_department_rounded, session.color),
          _insightCard(
              'PATTERN', pattern, Icons.waves_rounded, AppColors.text2),
        ],
      ),
    ]);
  }

  Widget _insightCard(
          String label, String value, IconData icon, Color iconColor) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 6),
            Text(label,
                style: AppText.ui(9,
                    color: AppColors.text3,
                    weight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ]),
          const Spacer(),
          // Value text is always white — no red/gold/green
          Text(value,
              style: AppText.ui(17,
                  color: AppColors.text1, weight: FontWeight.w800)),
        ]),
      );

  // ── helpers ───────────────────────────────────────────────────────────────

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
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

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: AppColors.bg,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: AppColors.text3),
          const SizedBox(width: 5),
          Text(label, style: AppText.ui(11, color: AppColors.text2)),
        ]),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAINTERS
// ═════════════════════════════════════════════════════════════════════════════

class _RingPainter extends CustomPainter {
  final double value;
  final Color trackColor;
  final Color arcColor;

  _RingPainter({
    required this.value,
    required this.trackColor,
    required this.arcColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(size.width, size.height) / 2 - 8;
    const sw = 7.0;

    // Track ring
    canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw);

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * value.clamp(0, 1),
      false,
      Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────

class _AccuracyLinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final double avg;

  _AccuracyLinePainter(
      {required this.points, required this.color, required this.avg});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final dx = size.width / (points.length - 1);
    final path = Path(), fill = Path();

    path.moveTo(0, size.height * (1 - points[0]));
    fill.moveTo(0, size.height);
    fill.lineTo(0, size.height * (1 - points[0]));

    for (int i = 1; i < points.length; i++) {
      final x = i * dx, y = size.height * (1 - points[i]);
      final px = (i - 1) * dx, py = size.height * (1 - points[i - 1]);
      path.quadraticBezierTo(px, py, (px + x) / 2, (py + y) / 2);
      fill.quadraticBezierTo(px, py, (px + x) / 2, (py + y) / 2);
      if (i == points.length - 1) {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    // Avg reference line
    canvas.drawLine(
      Offset(0, size.height * (1 - avg)),
      Offset(size.width, size.height * (1 - avg)),
      Paint()
        ..color = AppColors.text3.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Fill gradient
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Glow
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0));

    // Line
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    // Last-point dot
    final lx = (points.length - 1) * dx;
    final ly = size.height * (1 - points.last);
    canvas.drawCircle(Offset(lx, ly), 5, Paint()..color = color);
    canvas.drawCircle(
        Offset(lx, ly),
        5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_) => false;
}
