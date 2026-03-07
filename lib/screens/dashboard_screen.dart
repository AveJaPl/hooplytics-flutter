import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _selectedNav = 0;
  late AnimationController _entryController;
  late Animation<double> _entryFade;
  late Animation<double> _entrySlide;

  final List<_SessionData> _sessions = [
    _SessionData('Dziś', 'Wing Corner', 22, 30, const Color(0xFFFF6B1A)),
    _SessionData('Wtorek', 'Three Point', 14, 25, const Color(0xFF4CAF50)),
    _SessionData('Poniedziałek', 'Mid Range', 18, 22, const Color(0xFF2196F3)),
    _SessionData('Niedziela', 'Free Throw', 28, 30, const Color(0xFFFFAA00)),
  ];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    _entrySlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          // BG
          const _DashBackground(),

          SafeArea(
            child: AnimatedBuilder(
              animation: _entryController,
              builder: (context, child) {
                return Opacity(
                  opacity: _entryFade.value,
                  child: Transform.translate(
                    offset: Offset(0, _entrySlide.value),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildHeroStats(),
                          const SizedBox(height: 28),
                          _buildQuickActions(),
                          const SizedBox(height: 28),
                          _buildWeeklyChart(),
                          const SizedBox(height: 28),
                          _buildRecentSessions(),
                          const SizedBox(height: 28),
                          _buildCourtHeatmap(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom nav
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dobry wieczór, 👋',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kowalski',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          // Streak badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B1A).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF6B1A).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '7 dni',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF6B1A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B1A), Color(0xFFD94F0A)],
              ),
            ),
            child: Center(
              child: Text(
                'K',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1208), Color(0xFF12121A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF6B1A).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B1A).withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Skuteczność tygodniowa',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+4.2%',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '73',
                style: GoogleFonts.outfit(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              Text(
                '%',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFF6B1A),
                ),
              ),
              const Spacer(),
              _buildCircularProgress(0.73),
            ],
          ),
          const SizedBox(height: 20),
          // Mini stats row
          Row(
            children: [
              _buildMiniStat('Trafienia', '82', const Color(0xFF4CAF50)),
              _buildDivider(),
              _buildMiniStat('Próby', '112', Colors.white),
              _buildDivider(),
              _buildMiniStat('Sesje', '6', const Color(0xFFFFAA00)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(double value) {
    return SizedBox(
      width: 70,
      height: 70,
      child: CustomPaint(
        painter: _CircularProgressPainter(value),
        child: Center(
          child: Text(
            '${(value * 100).toInt()}%',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withOpacity(0.08),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction('🏀', 'Nowa\nSesja', const Color(0xFFFF6B1A)),
      _QuickAction('🎙️', 'Głos\nTryb', const Color(0xFF9C27B0)),
      _QuickAction('📊', 'Statys\ntyki', const Color(0xFF2196F3)),
      _QuickAction('🏆', 'Wyzy\nwania', const Color(0xFFFFAA00)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Szybkie akcje'),
        const SizedBox(height: 14),
        Row(
          children: actions
              .map((a) => Expanded(child: _QuickActionCard(action: a)))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Tygodniowy postęp'),
        const SizedBox(height: 14),
        Container(
          height: 140,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF12121A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: const _WeeklyBarChart(),
        ),
      ],
    );
  }

  Widget _buildRecentSessions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionTitle('Ostatnie sesje'),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: Text(
                'Zobacz wszystkie',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFFFF6B1A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._sessions.map((s) => _SessionCard(session: s)),
      ],
    );
  }

  Widget _buildCourtHeatmap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Mapa trafień'),
        const SizedBox(height: 14),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF12121A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: const _CourtHeatmapWidget(),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final items = [
      _NavItem(Icons.home_rounded, 'Strona'),
      _NavItem(Icons.sports_basketball_rounded, 'Trening'),
      _NavItem(Icons.bar_chart_rounded, 'Statystyki'),
      _NavItem(Icons.emoji_events_rounded, 'Nagrody'),
    ];

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (i) {
          final selected = _selectedNav == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedNav = i),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 70,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFF6B1A).withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      items[i].icon,
                      size: 22,
                      color: selected
                          ? const Color(0xFFFF6B1A)
                          : Colors.white.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].label,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected
                          ? const Color(0xFFFF6B1A)
                          : Colors.white.withOpacity(0.3),
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
}

// ──────────────────────────────────────────
//  Supporting Widgets
// ──────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: action.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: action.color.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Text(action.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final _SessionData session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final pct = (session.made / session.attempts * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: session.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.sports_basketball,
              color: session.color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.zone,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.day,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: session.made / session.attempts,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(session.color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pct%',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: session.color,
                ),
              ),
              Text(
                '${session.made}/${session.attempts}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart();

  @override
  Widget build(BuildContext context) {
    final data = [58.0, 65.0, 70.0, 62.0, 78.0, 73.0, 80.0];
    final days = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'];
    final maxVal = data.reduce(math.max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final isToday = i == 6;
        final pct = data[i] / maxVal;
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isToday)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B1A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${data[i].toInt()}%',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 600 + i * 80),
                  curve: Curves.easeOutCubic,
                  height: 70 * pct,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isToday
                          ? const [Color(0xFFFF6B1A), Color(0xFFFF9500)]
                          : [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05),
                            ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                days[i],
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: isToday
                      ? const Color(0xFFFF6B1A)
                      : Colors.white.withOpacity(0.3),
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CourtHeatmapWidget extends StatelessWidget {
  const _CourtHeatmapWidget();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: CustomPaint(
        painter: _HeatmapPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Court outline
    final courtPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;

    // Three point arc
    final arc = Rect.fromCenter(
      center: Offset(cx, size.height * 1.1),
      width: size.width * 0.85,
      height: size.width * 0.85,
    );
    canvas.drawArc(arc, math.pi * 1.1, math.pi * 0.8, false, courtPaint);

    // Key
    final keyRect = Rect.fromCenter(
      center: Offset(cx, size.height * 0.95),
      width: size.width * 0.3,
      height: size.height * 0.55,
    );
    canvas.drawRect(keyRect, courtPaint);

    // FT circle
    canvas.drawCircle(
      Offset(cx, size.height * 0.68),
      size.width * 0.09,
      courtPaint,
    );

    // Heatmap dots
    final zones = [
      _HeatZone(
        cx - size.width * 0.38,
        size.height * 0.5,
        0.9,
        const Color(0xFF4CAF50),
      ),
      _HeatZone(
        cx + size.width * 0.38,
        size.height * 0.5,
        0.4,
        const Color(0xFFFF3B3B),
      ),
      _HeatZone(cx, size.height * 0.2, 0.75, const Color(0xFFFFAA00)),
      _HeatZone(
        cx - size.width * 0.2,
        size.height * 0.65,
        0.85,
        const Color(0xFF4CAF50),
      ),
      _HeatZone(
        cx + size.width * 0.2,
        size.height * 0.65,
        0.6,
        const Color(0xFFFFAA00),
      ),
      _HeatZone(cx, size.height * 0.8, 0.95, const Color(0xFF4CAF50)),
    ];

    for (final z in zones) {
      final heatPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            z.color.withOpacity(0.5 * z.intensity),
            z.color.withOpacity(0.15 * z.intensity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(z.x, z.y), radius: 38));
      canvas.drawCircle(Offset(z.x, z.y), 38, heatPaint);

      // Center dot
      canvas.drawCircle(
        Offset(z.x, z.y),
        5,
        Paint()..color = z.color.withOpacity(0.9),
      );
    }

    // Legend
    final legendItems = [
      _LegendItem(const Color(0xFF4CAF50), 'Dobry'),
      _LegendItem(const Color(0xFFFFAA00), 'Średni'),
      _LegendItem(const Color(0xFFFF3B3B), 'Słaby'),
    ];

    double lx = 12;
    for (final item in legendItems) {
      canvas.drawCircle(
        Offset(lx + 5, size.height - 14),
        5,
        Paint()..color = item.color,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: item.label,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx + 14, size.height - 19));
      lx += 14 + tp.width + 12;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircularProgressPainter extends CustomPainter {
  final double value;
  const _CircularProgressPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * value;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // Progress arc
    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFFFF6B1A), Color(0xFFFF9500)],
        startAngle: 0,
        endAngle: math.pi * 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashBackground extends StatelessWidget {
  const _DashBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _DashBgPainter(),
    );
  }
}

class _DashBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFF6B1A).withOpacity(0.07),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(size.width * 0.8, 0), radius: 300),
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ──────────────────────────────────────────
//  Data Models
// ──────────────────────────────────────────

class _SessionData {
  final String day, zone;
  final int made, attempts;
  final Color color;
  const _SessionData(this.day, this.zone, this.made, this.attempts, this.color);
}

class _QuickAction {
  final String emoji, label;
  final Color color;
  const _QuickAction(this.emoji, this.label, this.color);
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _HeatZone {
  final double x, y, intensity;
  final Color color;
  const _HeatZone(this.x, this.y, this.intensity, this.color);
}

class _LegendItem {
  final Color color;
  final String label;
  const _LegendItem(this.color, this.label);
}
