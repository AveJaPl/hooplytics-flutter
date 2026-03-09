import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'session_detail_screen.dart';
import 'session_setup_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  MANUAL SESSION DETAIL SCREEN
//  For sessions logged without live shot tracking (just totals).
//  Shows court highlight, accuracy ring, comparison stats.
// ═════════════════════════════════════════════════════════════════════════════

class ManualSessionDetailScreen extends StatefulWidget {
  final HoopSession session;
  const ManualSessionDetailScreen({super.key, required this.session});
  @override
  State<ManualSessionDetailScreen> createState() =>
      _ManualSessionDetailScreenState();
}

class _ManualSessionDetailScreenState extends State<ManualSessionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550))
    ..forward();

  HoopSession get s => widget.session;
  int get pct => (s.made / s.attempts * 100).round();

  Color get pctColor {
    if (pct >= 70) return AppColors.green;
    if (pct >= 50) return AppColors.gold;
    return AppColors.red;
  }

  String get grade {
    if (pct >= 85) return 'S';
    if (pct >= 75) return 'A';
    if (pct >= 65) return 'B';
    if (pct >= 50) return 'C';
    return 'D';
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
          _topBar(context),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 60),
              child: Column(children: [
                _heroSection(),
                const SizedBox(height: 28),
                _courtSection(),
                const SizedBox(height: 28),
                _statsRow(),
                const SizedBox(height: 28),
                _performanceSection(),
                const SizedBox(height: 28),
                _insightsSection(),
              ]),
            ),
          ),
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
                    size: 18, color: AppColors.text2)),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SESSION DETAILS',
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.8,
                    weight: FontWeight.w700)),
            Text(s.zone, style: AppText.ui(15, weight: FontWeight.w700)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
                border:
                    Border.all(color: AppColors.blue.withValues(alpha: 0.28))),
            child: Text('MANUAL',
                style: AppText.ui(9,
                    weight: FontWeight.w800,
                    color: AppColors.blue,
                    letterSpacing: 0.8)),
          ),
        ]),
      );

  // ── hero ──────────────────────────────────────────────────────────────────

  Widget _heroSection() {
    final diff = pct - s.globalAvgPct;
    final diffStr = diff >= 0 ? '+$diff%' : '$diff%';
    final diffColor = diff >= 0 ? AppColors.green : AppColors.red;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          pctColor.withValues(alpha: 0.18),
          pctColor.withValues(alpha: 0.04)
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: pctColor.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.zone, style: AppText.ui(22, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(
                s.mode == SessionMode.position
                    ? Icons.place_rounded
                    : Icons.crop_square_rounded,
                size: 12,
                color: AppColors.text3),
            const SizedBox(width: 5),
            Text(s.mode == SessionMode.position ? 'Position' : 'Range',
                style: AppText.ui(12, color: AppColors.text3)),
          ]),
          const SizedBox(height: 16),
          // Date chip
          _chip(Icons.calendar_today_rounded, s.dateLabel),
          const SizedBox(height: 6),
          // Global avg comparison chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: diffColor.withValues(alpha: 0.10),
                border: Border.all(color: diffColor.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  diff >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 13,
                  color: diffColor),
              const SizedBox(width: 5),
              Text('$diffStr vs avg',
                  style: AppText.ui(11,
                      weight: FontWeight.w600, color: diffColor)),
            ]),
          ),
        ])),
        const SizedBox(width: 20),
        // Ring + grade
        Column(children: [
          SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                  painter: _RingPainter(pct / 100, pctColor),
                  child: Center(
                      child: Text('$pct%',
                          style: AppText.display(22, color: pctColor))))),
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: pctColor.withValues(alpha: 0.10),
                  border: Border.all(color: pctColor.withValues(alpha: 0.30))),
              child: Center(
                  child: Text(grade,
                      style: AppText.display(20, color: pctColor)))),
        ]),
      ]),
    );
  }

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

  // ── court display ─────────────────────────────────────────────────────────

  Widget _courtSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('COURT POSITION'),
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
                  if (s.mode == SessionMode.range)
                    Positioned.fill(
                        child: CustomPaint(
                            painter: RangeZonePainter(geo, s.id, const [
                      RangeZone('layup', 'Layup', 0),
                      RangeZone('close', 'Close Shot', 1),
                      RangeZone('mid', 'Mid Range', 2),
                      RangeZone('three', 'Three Point', 3),
                    ]))),
                  if (s.mode == SessionMode.position)
                    ...geo.spots.where((sp) => sp.id == s.id).map((sp) =>
                        Positioned(
                            left: sp.fx * geo.w - 28,
                            top: sp.fy * geo.h - 28,
                            child: CourtSpotWidget(
                                selected: true, label: sp.label))),
                ]);
              }),
            ),
          ),
        ),
      ]);

  // ── stats row ─────────────────────────────────────────────────────────────

  Widget _statsRow() => Row(children: [
        _statCard('MADE', '${s.made}', s.color),
        const SizedBox(width: 12),
        _statCard('MISSED', '${s.attempts - s.made}', AppColors.red),
        const SizedBox(width: 12),
        _statCard('TOTAL', '${s.attempts}', AppColors.text1),
      ]);

  Widget _statCard(String label, String value, Color vc) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(value, style: AppText.display(30, color: vc)),
            const SizedBox(height: 4),
            Text(label,
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.2,
                    weight: FontWeight.w700)),
          ])));

  // ── performance ───────────────────────────────────────────────────────────

  Widget _performanceSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('PERFORMANCE'),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              // Accuracy bar
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Your accuracy',
                                style: AppText.ui(12, color: AppColors.text2)),
                            Text('$pct%',
                                style: AppText.ui(13,
                                    weight: FontWeight.w700, color: pctColor)),
                          ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                              value: pct / 100,
                              backgroundColor: AppColors.borderSub,
                              valueColor: AlwaysStoppedAnimation(pctColor),
                              minHeight: 7)),
                    ])),
              ]),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.borderSub),
              const SizedBox(height: 16),
              // Global avg bar
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Global average',
                                style: AppText.ui(12, color: AppColors.text2)),
                            Text('${s.globalAvgPct}%',
                                style: AppText.ui(13,
                                    weight: FontWeight.w700,
                                    color: AppColors.text3)),
                          ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                              value: s.globalAvgPct / 100,
                              backgroundColor: AppColors.borderSub,
                              valueColor:
                                  const AlwaysStoppedAnimation(AppColors.text3),
                              minHeight: 7)),
                    ])),
              ]),
              const SizedBox(height: 16),
              // Net result
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: pctColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: pctColor.withValues(alpha: 0.20))),
                  child: Row(children: [
                    Icon(
                        pct >= s.globalAvgPct
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                        color: pctColor),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                      pct >= s.globalAvgPct
                          ? 'Above average by ${pct - s.globalAvgPct}% — great session!'
                          : 'Below average by ${s.globalAvgPct - pct}% — keep training!',
                      style: AppText.ui(12, color: pctColor),
                    )),
                  ])),
            ])),
      ]);

  // ── insights ──────────────────────────────────────────────────────────────

  Widget _insightsSection() {
    final missRate = ((s.attempts - s.made) / s.attempts * 100).round();
    final hitStr = pct >= 70
        ? 'Elite'
        : pct >= 55
            ? 'Above avg'
            : pct >= 40
                ? 'Developing'
                : 'Keep going';
    final volume = s.attempts >= 50
        ? 'High'
        : s.attempts >= 25
            ? 'Medium'
            : 'Light';
    final quality = s.made >= 35
        ? 'Premium'
        : s.made >= 20
            ? 'Solid'
            : 'Building';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('SESSION INSIGHTS'),
      GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _insightCard(
                'HIT RATE', hitStr, Icons.sports_basketball_rounded, s.color),
            _insightCard(
                'MISS RATE', '$missRate%', Icons.close_rounded, AppColors.red),
            _insightCard('VOLUME', volume, Icons.stacked_bar_chart_rounded,
                AppColors.blue),
            _insightCard(
                'QUALITY', quality, Icons.diamond_rounded, AppColors.gold),
          ]),
    ]);
  }

  Widget _insightCard(String label, String value, IconData icon, Color color) =>
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: AppText.ui(9,
                      color: AppColors.text3,
                      weight: FontWeight.w700,
                      letterSpacing: 0.5))
            ]),
            const Spacer(),
            Text(value,
                style: AppText.ui(17,
                    color: Colors.white, weight: FontWeight.w800)),
          ]));

  Widget _sectionLabel(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Text(t,
            style: AppText.ui(9,
                color: AppColors.text3,
                letterSpacing: 1.6,
                weight: FontWeight.w700)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppColors.borderSub)),
      ]));
}

// ── Ring chart painter ────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  _RingPainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = (size.width.clamp(size.height, double.infinity)) / 2 - 8;
    const strokeW = 7.0;
    // Track
    canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = AppColors.borderSub
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW);
    // Arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -3.14159 / 2,
      2 * 3.14159 * value.clamp(0, 1),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
