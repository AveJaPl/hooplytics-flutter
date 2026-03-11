import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/auth_service.dart';
import 'session_setup_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'train_screen.dart';
import 'manual_entry_screen.dart';
import 'history_screen.dart';
import '../services/session_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _navIndex = 0;

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  final _authService = AuthService();
  final _sessionService = SessionService();
  int _chartPeriod = 0; // 0 = 7D, 1 = 6M
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    setState(() {
      _statsFuture = _sessionService.getStatsData();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  String get _userName {
    final user = _authService.currentUser;
    if (user == null) return 'Player';
    final meta = user.userMetadata;
    if (meta != null && meta['display_name'] != null) {
      return meta['display_name'] as String;
    }
    return user.email?.split('@').first ?? 'Player';
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    final slide = Tween(
      begin: 16.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          FadeTransition(
            opacity: fade,
            child: AnimatedBuilder(
              animation: slide,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, slide.value),
                child: child,
              ),
              child: _buildCurrentTab(),
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildNav()),
        ],
      ),
    );
  }

  // ── Tab Routing ─────────────────────────────────────────────────────────────

  Widget _buildCurrentTab() {
    switch (_navIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return const TrainScreen();
      case 2:
        return const StatsScreen();
      case 3:
        return const HistoryScreen();
      case 4:
        return const ProfileScreen();
      default:
        return _buildHomeTab();
    }
  }

  // ── Home Tab ────────────────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: [
              _buildTopBar(0),
              const Expanded(
                  child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold))),
            ],
          );
        }

        if (snapshot.hasError) {
          return Column(
            children: [
              _buildTopBar(0),
              Expanded(
                child: Center(
                  child: Text('Error loading dashboard: ${snapshot.error}',
                      style: AppText.ui(14, color: AppColors.red)),
                ),
              ),
            ],
          );
        }

        final d = snapshot.data ?? {};
        final streak = d['currentStreak'] as int? ?? 0;

        return Column(
          children: [
            _buildTopBar(streak),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _loadStats();
                  await _statsFuture;
                },
                color: AppColors.gold,
                backgroundColor: AppColors.surface,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),
                      _buildSectionLabel('QUICK START', padding: true),
                      const SizedBox(height: 14),
                      _buildQuickStart(),
                      const SizedBox(height: 28),
                      _buildSectionLabel('TREND', padding: true),
                      const SizedBox(height: 14),
                      _trendChart(
                        List<double>.from(d['weekPct'] ?? []),
                        List<String>.from(d['weekLabels'] ?? []),
                        List<double>.from(d['monthPct'] ?? []),
                        List<String>.from(d['monthLabels'] ?? []),
                      ),
                      const SizedBox(height: 28),
                      _buildSectionLabel('CONSISTENCY', padding: true),
                      const SizedBox(height: 14),
                      _calendarHeatmap(
                        (d['calendarData'] as List? ?? [])
                            .map((row) => List<double>.from(row as List))
                            .toList(),
                        (d['consistencyScore'] ?? 0.0).toDouble(),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar(int streak) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GOOD EVENING',
                  style: AppText.ui(
                    11,
                    color: AppColors.text2,
                    letterSpacing: 1.4,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(_userName, style: AppText.ui(24, weight: FontWeight.w800)),
              ],
            ),
            const Spacer(),
            if (streak > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '$streak day streak',
                      style: AppText.ui(
                        12,
                        weight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Hero Card ───────────────────────────────────────────────────────────────

  // ── Quick Start ──────────────────────────────────────────────────────────────

  Widget _buildQuickStart() {
    final cards = [
      _QCard(
        'NEW SESSION',
        Icons.add_rounded,
        AppColors.gold,
        AppColors.goldSoft,
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const SessionSetupScreen(),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (_, a, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(
                    CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
          ),
        ),
      ),
      _QCard(
        'MANUAL ENTRY',
        Icons.edit_note_rounded,
        AppColors.blue,
        AppColors.blueSoft,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
        ),
      ),
    ];
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: cards.length,
        itemBuilder: (_, i) => _QuickCard(
          card: cards[i],
          width: MediaQuery.of(context).size.width / 2 - 30,
        ),
      ),
    );
  }

  // ── Bottom Nav ──────────────────────────────────────────────────────────────

  Widget _buildNav() {
    final items = [
      const _Nav(Icons.home_outlined, Icons.home_rounded, 'Home'),
      const _Nav(
        Icons.sports_basketball_outlined,
        Icons.sports_basketball_rounded,
        'Train',
      ),
      const _Nav(Icons.show_chart_rounded, Icons.show_chart_rounded, 'Stats'),
      const _Nav(Icons.history_rounded, Icons.history_rounded, 'History'),
      const _Nav(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];

    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = _navIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _navIndex = i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    active ? items[i].activeIcon : items[i].icon,
                    size: 22,
                    color: active ? AppColors.gold : AppColors.text2,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    items[i].label,
                    style: AppText.ui(
                      12,
                      weight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? AppColors.gold : AppColors.text2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(
    String label, {
    bool header = false,
    bool padding = false,
  }) {
    Widget content = Row(
      children: [
        Text(
          label,
          style: AppText.ui(
            11,
            weight: FontWeight.w800,
            color: AppColors.text2,
            letterSpacing: 1.4,
          ),
        ),
        if (header) ...[
          const Spacer(),
          Text(
            'See all',
            style: AppText.ui(
              12,
              color: AppColors.gold,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
    if (padding) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: content,
      );
    }
    return content;
  }

  // ── Trend Chart ─────────────────────────────────────────────────────────────

  Widget _trendChart(List<double> weekPct, List<String> weekLabels,
      List<double> monthPct, List<String> monthLabels) {
    final data = _chartPeriod == 0 ? weekPct : monthPct;
    final labels = _chartPeriod == 0 ? weekLabels : monthLabels;
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Text(
                    '${(data.where((v) => v > 0).reduce(math.min) * 100).round()}% low',
                    style: AppText.ui(12, color: AppColors.text2)),
                const Spacer(),
                Text('${(data.reduce(math.max) * 100).round()}% peak',
                    style: AppText.ui(11, color: AppColors.green)),
              ]),
            ),
            const SizedBox(height: 4),
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

// ── Consistency Calendar ──────────────────────────────────────────────────

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
            Row(children: [
              const SizedBox(width: 8),
              ...['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => Expanded(
                    child: Center(
                        child: Text(d,
                            style: AppText.ui(12,
                                color: AppColors.text2,
                                weight: FontWeight.w700))),
                  )),
            ]),
            const SizedBox(height: 8),
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
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('Less ', style: AppText.ui(12, color: AppColors.text2)),
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
              Text(' More', style: AppText.ui(12, color: AppColors.text2)),
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
}

// ── Sub Widgets ──────────────────────────────────────────────────────────────

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

class _QuickCard extends StatelessWidget {
  final _QCard card;
  final double width;
  const _QuickCard({required this.card, this.width = 140});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: card.onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card.bgColor,
          border: Border.all(color: card.accentColor.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(card.icon, color: card.accentColor, size: 22),
            const Spacer(),
            Text(
              card.label,
              style: AppText.ui(
                11,
                weight: FontWeight.w700,
                color: card.accentColor,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Removed _SessionRow & _ZoneTile

// ── Data Models ───────────────────────────────────────────────────────────────

class _QCard {
  final String label;
  final IconData icon;
  final Color accentColor, bgColor;
  final VoidCallback? onTap;
  const _QCard(this.label, this.icon, this.accentColor, this.bgColor,
      {this.onTap});
}

// Removed _Zone

class _Nav {
  final IconData icon, activeIcon;
  final String label;
  const _Nav(this.icon, this.activeIcon, this.label);
}
