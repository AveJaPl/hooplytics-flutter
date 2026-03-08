import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/auth_service.dart';
import 'session_setup_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'train_screen.dart';
import 'manual_entry_screen.dart';
import 'session_detail_screen.dart';
import 'history_screen.dart';

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

  // ── Sample data ──
  final _sessions = [
    HoopSession(
      id: 'right_wing',
      mode: SessionMode.position,
      zone: 'Right Wing',
      dateLabel: 'Today · 6:30 PM',
      date: DateTime.now(),
      made: 22,
      attempts: 30,
      color: AppColors.gold,
      isLive: true,
      swishPct: 45,
      maxStreak: 8,
      globalAvgPct: 62,
      shotHistory: const [
        true,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        true,
        false,
        true,
        true
      ],
    ),
    HoopSession(
      id: 'three_pt',
      mode: SessionMode.range,
      zone: 'Three Point',
      dateLabel: 'Tuesday · 7:00 PM',
      date: DateTime.now().subtract(const Duration(days: 1)),
      made: 14,
      attempts: 25,
      color: AppColors.blue,
      isLive: false,
      swishPct: 38,
      globalAvgPct: 42,
    ),
    HoopSession(
      id: 'mid',
      mode: SessionMode.range,
      zone: 'Mid Range',
      dateLabel: 'Monday · 5:45 PM',
      date: DateTime.now().subtract(const Duration(days: 2)),
      made: 18,
      attempts: 22,
      color: AppColors.green,
      isLive: true,
      swishPct: 50,
      maxStreak: 12,
      globalAvgPct: 55,
      shotHistory: const [
        true,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        true,
        true
      ],
    ),
    HoopSession(
      id: 'free_throw',
      mode: SessionMode.position,
      zone: 'Free Throw',
      dateLabel: 'Sunday · 8:00 AM',
      date: DateTime.now().subtract(const Duration(days: 3)),
      made: 28,
      attempts: 30,
      color: AppColors.green,
      isLive: false,
      swishPct: 60,
      globalAvgPct: 75,
    ),
  ];

  final _weekData = const [54.0, 61.0, 68.0, 59.0, 76.0, 71.0, 80.0];
  final _weekLabels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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

  String get _initials {
    final parts = _userName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _userName.substring(0, math.min(2, _userName.length)).toUpperCase();
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
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                _buildHeroCard(),
                const SizedBox(height: 28),
                _buildSectionLabel('THIS WEEK', padding: true),
                const SizedBox(height: 14),
                _buildWeekChart(),
                const SizedBox(height: 28),
                _buildSectionLabel('QUICK START', padding: true),
                const SizedBox(height: 14),
                _buildQuickStart(),
                const SizedBox(height: 28),
                _buildSectionLabel(
                  'RECENT SESSIONS',
                  header: true,
                  padding: true,
                ),
                const SizedBox(height: 14),
                _buildSessionList(),
                const SizedBox(height: 28),
                _buildSectionLabel('SHOT ZONES', padding: true),
                const SizedBox(height: 14),
                _buildZoneGrid(),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GOOD EVENING',
                  style: AppText.ui(
                    10,
                    color: AppColors.text3,
                    letterSpacing: 1.8,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(_userName, style: AppText.ui(24, weight: FontWeight.w800)),
              ],
            ),
            const Spacer(),
            // Streak pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    '7 day streak',
                    style: AppText.ui(
                      12,
                      weight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Avatar
            GestureDetector(
              onLongPress: () async {
                await _authService.signOut();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: AppText.ui(
                      13,
                      weight: FontWeight.w700,
                      color: AppColors.text2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero Card ───────────────────────────────────────────────────────────────

  Widget _buildHeroCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SHOOTING %',
                        style: AppText.ui(
                          10,
                          color: AppColors.text3,
                          letterSpacing: 1.8,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '73',
                            style: AppText.display(72, color: AppColors.text1),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12, left: 2),
                            child: Text(
                              '%',
                              style: AppText.display(28, color: AppColors.gold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.greenSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '↑ 4.2%',
                              style: AppText.ui(
                                11,
                                weight: FontWeight.w700,
                                color: AppColors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'vs last week',
                            style: AppText.ui(12, color: AppColors.text3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const _RingChart(value: 0.73, size: 84),
              ],
            ),
            const SizedBox(height: 24),
            Container(height: 1, color: AppColors.borderSub),
            const SizedBox(height: 20),
            const Row(
              children: [
                _StatTile(label: 'MADE', value: '82', color: AppColors.text1),
                _StatTileDivider(),
                _StatTile(
                  label: 'ATTEMPTS',
                  value: '112',
                  color: AppColors.text1,
                ),
                _StatTileDivider(),
                _StatTile(label: 'SESSIONS', value: '6', color: AppColors.gold),
                _StatTileDivider(),
                _StatTile(
                  label: 'BEST ZONE',
                  value: 'FT',
                  color: AppColors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Week Chart ──────────────────────────────────────────────────────────────

  Widget _buildWeekChart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 150,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: _BarChart(data: _weekData, labels: _weekLabels),
      ),
    );
  }

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

  // ── Session List ────────────────────────────────────────────────────────────

  Widget _buildSessionList() {
    return Column(
      children: _sessions
          .map(
            (s) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: _SessionRow(session: s),
            ),
          )
          .toList(),
    );
  }

  // ── Zone Grid ───────────────────────────────────────────────────────────────

  Widget _buildZoneGrid() {
    final zones = [
      const _Zone('Corner 3', '84%', AppColors.green),
      const _Zone('Wing 3', '61%', AppColors.gold),
      const _Zone('Mid Range', '73%', AppColors.gold),
      const _Zone('Elbow', '68%', AppColors.gold),
      const _Zone('Free Throw', '93%', AppColors.green),
      const _Zone('Layup', '88%', AppColors.green),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemCount: zones.length,
        itemBuilder: (_, i) => _ZoneTile(zone: zones[i]),
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
                    color: active ? AppColors.gold : AppColors.text3,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    items[i].label,
                    style: AppText.ui(
                      10,
                      weight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? AppColors.gold : AppColors.text3,
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
            10,
            weight: FontWeight.w700,
            color: AppColors.text3,
            letterSpacing: 1.6,
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
}

// ── Sub Widgets ──────────────────────────────────────────────────────────────

class _RingChart extends StatelessWidget {
  final double value;
  final double size;
  const _RingChart({required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RingPainter(value)),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  const _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 5;
    const sw = 5.0;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppText.ui(18, weight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppText.ui(9, color: AppColors.text3, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

class _StatTileDivider extends StatelessWidget {
  const _StatTileDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: AppColors.borderSub);
}

class _BarChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  const _BarChart({required this.data, required this.labels});

  @override
  Widget build(BuildContext context) {
    final maxV = data.reduce(math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(data.length, (i) {
        final isLast = i == data.length - 1;
        final pct = data[i] / maxV;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isLast)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '${data[i].toInt()}%',
                      style: AppText.ui(
                        10,
                        weight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                  child: Container(
                    height: 72 * pct,
                    decoration: BoxDecoration(
                      color: isLast ? AppColors.gold : AppColors.surfaceHi,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  labels[i],
                  style: AppText.ui(
                    11,
                    color: isLast ? AppColors.gold : AppColors.text3,
                    weight: isLast ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
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

class _SessionRow extends StatelessWidget {
  final HoopSession session;
  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final pct = (session.made / session.attempts * 100).round();
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, __) => SessionDetailScreen(
            session: session,
            animation: animation,
          ),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: child,
          ),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 42,
              decoration: BoxDecoration(
                color: session.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.zone,
                    style: AppText.ui(14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    session.dateLabel,
                    style: AppText.ui(12, color: AppColors.text3),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: session.made / session.attempts,
                      backgroundColor: AppColors.borderSub,
                      valueColor: AlwaysStoppedAnimation(session.color),
                      minHeight: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Hero(
                  tag: 'session_pct_${session.dateLabel}', // unique tag
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      '$pct%',
                      style: AppText.ui(
                        18,
                        weight: FontWeight.w700,
                        color: session.color,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${session.made}/${session.attempts}',
                  style: AppText.ui(11, color: AppColors.text3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneTile extends StatelessWidget {
  final _Zone zone;
  const _ZoneTile({required this.zone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(zone.pct, style: AppText.display(26, color: zone.color)),
          Text(
            zone.label,
            style: AppText.ui(
              11,
              color: AppColors.text2,
              weight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Data Models ───────────────────────────────────────────────────────────────

class _QCard {
  final String label;
  final IconData icon;
  final Color accentColor, bgColor;
  final VoidCallback? onTap;
  const _QCard(this.label, this.icon, this.accentColor, this.bgColor,
      {this.onTap});
}

class _Zone {
  final String label, pct;
  final Color color;
  const _Zone(this.label, this.pct, this.color);
}

class _Nav {
  final IconData icon, activeIcon;
  final String label;
  const _Nav(this.icon, this.activeIcon, this.label);
}
