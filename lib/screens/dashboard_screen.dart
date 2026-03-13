import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../main.dart';
import '../utils/haptics.dart';
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
  int _chartPeriod = 0;

  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650))
    ..forward();

  final _authService = AuthService();
  final _sessionService = SessionService();
  late Future<Map<String, dynamic>> _statsFuture;
  StreamSubscription? _sessionSub;
  StreamSubscription? _authSub;

  void _reload() => setState(() {
        _statsFuture = _sessionService.getStatsData();
        _loadUserSettings();
      });

  int _weeklyMakesGoal = 200;

  @override
  void initState() {
    super.initState();
    _statsFuture = _sessionService.getStatsData();
    _loadUserSettings();
    _sessionSub = _sessionService.updates.listen((_) => _reload());
    _authSub = _authService.updates.listen((_) => _reload());
  }

  void _loadUserSettings() {
    final user = _authService.currentUser;
    if (user != null && user.userMetadata != null) {
      final meta = user.userMetadata!;
      setState(() {
        _weeklyMakesGoal = meta['weekly_makes_goal'] as int? ?? 200;
        Haptics.enabled = meta['haptics_enabled'] as bool? ?? true;
      });
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _sessionSub?.cancel();
    _authSub?.cancel();
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
    final slide = Tween(begin: 16.0, end: 0.0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        FadeTransition(
          opacity: fade,
          child: AnimatedBuilder(
            animation: slide,
            builder: (_, child) => Transform.translate(
                offset: Offset(0, slide.value), child: child),
            child: _tabBody(),
          ),
        ),
        Positioned(bottom: 0, left: 0, right: 0, child: _nav()),
      ]),
    );
  }

  Widget _tabBody() {
    switch (_navIndex) {
      case 1:
        return const TrainScreen();
      case 2:
        return const StatsScreen();
      case 3:
        return const HistoryScreen();
      case 4:
        return const ProfileScreen();
      default:
        return _homeTab();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HOME TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _homeTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Column(children: [
            _topBar(0),
            const Expanded(
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.gold))),
          ]);
        }
        if (snap.hasError) {
          return Column(children: [
            _topBar(0),
            Expanded(
                child: Center(
                    child: Text('${snap.error}',
                        style: AppText.ui(13, color: AppColors.red)))),
          ]);
        }

        final d = snap.data ?? {};
        final streak = d['currentStreak'] as int? ?? 0;
        final weekPct = List<double>.from(d['weekPct'] ?? []);
        final weekCounts = List<int>.from(d['weekCounts'] ?? []);
        final weekLabels = List<String>.from(d['weekLabels'] ?? []);
        final monthPct = List<double>.from(d['monthPct'] ?? []);
        final monthCounts = List<int>.from(d['monthCounts'] ?? []);
        final monthLabels = List<String>.from(d['monthLabels'] ?? []);
        final weeklyMade = d['weeklyMade'] as int? ?? 0;

        return Column(children: [
          _topBar(streak),
          Expanded(
              child: RefreshIndicator(
            onRefresh: () async {
              _reload();
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
                    const SizedBox(height: 16),

                    const SizedBox(height: 16),

                    // 1. Log session
                    _label('LOG SESSION'),
                    const SizedBox(height: 12),
                    _logActions(),
                    const SizedBox(height: 28),

                    // 2. Quote of the day
                    _label('QUOTE OF THE DAY'),
                    const SizedBox(height: 12),
                    _quoteOfTheDay(),
                    const SizedBox(height: 28),

                    // 3. Weekly goal
                    _label('WEEKLY GOAL'),
                    const SizedBox(height: 12),
                    _weeklyGoal(weeklyMade),
                    const SizedBox(height: 28),

                    // 4. Accuracy trend
                    _label('ACCURACY TREND'),
                    const SizedBox(height: 12),
                    _trendChart(weekPct, weekLabels, monthPct, monthLabels),
                    const SizedBox(height: 28),
                    
                    // 5. Sessions chart
                    _label('SESSIONS'),
                    const SizedBox(height: 12),
                    _sessionsBarChart(weekCounts, weekLabels, monthCounts, monthLabels),
                    const SizedBox(height: 28),

                    // 6. Consistency calendar
                    _label('CONSISTENCY'),
                    const SizedBox(height: 12),
                    _calendarHeatmap(
                      (d['calendarData'] as List? ?? [])
                          .map((r) => List<double>.from(r as List))
                          .toList(),
                      (d['consistencyScore'] ?? 0.0).toDouble(),
                    ),
                    const SizedBox(height: 28),

                  ]),
            ),
          )),
        ]);
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'GOOD MORNING';
    if (hour >= 12 && hour < 18) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _topBar(int streak) => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getGreeting(),
                        style: AppText.ui(11,
                            color: AppColors.text2,
                            letterSpacing: 1.4,
                            weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(_userName,
                        style: AppText.ui(24, weight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            if (streak > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.gold)),
                  const SizedBox(width: 7),
                  Text('$streak day streak',
                      style: AppText.ui(12,
                          weight: FontWeight.w600, color: AppColors.gold)),
                ]),
              ),
          ]),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  1. LOG SESSION CARDS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _logActions() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
                child: _LogCard(
              onTap: () {
                Haptics.heavyImpact();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SessionSetupScreen()));
              },
              gradient: const LinearGradient(
                  colors: [Color(0xFFD4A843), Color(0xFF9A6F1F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              shadowColor: AppColors.gold.withValues(alpha: 0.28),
              watermarkIcon: Icons.sports_basketball_rounded,
              watermarkAlpha: 0.16,
              iconWidget: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.play_arrow_rounded,
                    size: 20, color: Colors.white),
              ),
              title: 'Live Session',
              titleColor: Colors.white,
              subtitle: 'Track in real time',
              subtitleColor: Colors.white.withValues(alpha: 0.60),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _LogCard(
              onTap: () {
                Haptics.lightImpact();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManualEntryScreen()));
              },
              bgColor: AppColors.surface,
              borderColor: AppColors.border,
              watermarkIcon: Icons.edit_note_rounded,
              watermarkAlpha: 0.18,
              iconWidget: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: AppColors.surfaceHi,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                child: const Icon(Icons.edit_rounded,
                    size: 17, color: AppColors.text2),
              ),
              title: 'Manual Entry',
              titleColor: AppColors.text1,
              subtitle: 'Log a past session',
              subtitleColor: AppColors.text3,
            )),
          ]),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  2. WEEKLY GOAL
  // ══════════════════════════════════════════════════════════════════════════

  Widget _weeklyGoal(int made) {
    final target = _weeklyMakesGoal;
    final pct = (made / target).clamp(0.0, 1.0);
    final left = math.max(0, target - made);
    final done = made >= target;
    final daysLeft = math.max(0, 7 - DateTime.now().weekday);

    final motivation = done
        ? 'Goal smashed! Consider raising the bar 🏆'
        : pct >= 0.75
            ? '$left more makes to close the week strong.'
            : daysLeft > 0
                ? '$daysLeft days left — ~${(left / daysLeft).round()} makes/day to go.'
                : 'Last chance today — $left makes to go!';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('MAKES THIS WEEK',
                style: AppText.ui(10,
                    color: AppColors.text3,
                    letterSpacing: 1.4,
                    weight: FontWeight.w700)),
            const Spacer(),
            if (done)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.28)),
                ),
                child: Text('DONE ✓',
                    style: AppText.ui(9,
                        weight: FontWeight.w800, color: AppColors.gold)),
              )
            else
              Text('$daysLeft days left',
                  style: AppText.ui(11, color: AppColors.text3)),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$made',
                style: AppText.display(32, color: done ? AppColors.gold : AppColors.text1)),
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 6),
              child: Text('/ $target',
                  style: AppText.ui(16,
                      color: AppColors.text3, weight: FontWeight.w600)),
            ),
            const Spacer(),
            Text('${(pct * 100).round()}%',
                style: AppText.ui(15,
                    weight: FontWeight.w700, color: done ? AppColors.gold : AppColors.text2)),
          ]),
          const SizedBox(height: 12),
          Row(
              children: List.generate(10, (i) {
            final filled = (pct * 10).round();
            return Expanded(
                child: Padding(
              padding: EdgeInsets.only(right: i < 9 ? 3 : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 7,
                decoration: BoxDecoration(
                  color: i < filled ? AppColors.gold : AppColors.borderSub,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ));
          })),
          const SizedBox(height: 14),
          Text(motivation, style: AppText.ui(12, color: AppColors.text2)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  3. ACCURACY TREND
  // ══════════════════════════════════════════════════════════════════════════

  Widget _trendChart(List<double> wPct, List<String> wLbl, List<double> mPct,
      List<String> mLbl) {
    final data = _chartPeriod == 0 ? wPct : mPct;
    final labels = _chartPeriod == 0 ? wLbl : mLbl;
    final hasData = data.any((v) => v > 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  _PeriodBtn('7D', _chartPeriod == 0,
                      () => setState(() => _chartPeriod = 0)),
                  _PeriodBtn('6M', _chartPeriod == 1,
                      () => setState(() => _chartPeriod = 1)),
                ]),
              ),
            ]),
          ),
          if (hasData) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(children: [
                Text(
                    '${(data.where((v) => v > 0).reduce(math.min) * 100).round()}% low',
                    style: AppText.ui(12, color: AppColors.text2)),
                const Spacer(),
                Text('${(data.reduce(math.max) * 100).round()}% peak',
                    style: AppText.ui(11, color: AppColors.green)),
              ]),
            ),
            SizedBox(
                height: 160,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: CustomPaint(
                      painter: _LineChartPainter(data: data, labels: labels),
                      size: Size.infinite),
                )),
          ] else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: Text('No data yet',
                      style: AppText.ui(13, color: AppColors.text3))),
            ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  4. CONSISTENCY CALENDAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _calendarHeatmap(List<List<double>> cal, double score) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(20)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                  '${cal.expand((r) => r).where((v) => v > 0).length} sessions · 5 weeks',
                  style: AppText.ui(13, weight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Text('Consistency: ',
                      style: AppText.ui(11, color: AppColors.text2)),
                  Text('${(score * 100).round()}%',
                      style: AppText.ui(11,
                          weight: FontWeight.w700, color: AppColors.gold)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              const SizedBox(width: 8),
              ...['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => Expanded(
                  child: Center(
                      child: Text(d,
                          style: AppText.ui(12,
                              color: AppColors.text2,
                              weight: FontWeight.w700))))),
            ]),
            const SizedBox(height: 8),
            ...cal.map((week) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const SizedBox(width: 8),
                    ...week.map((v) => Expanded(
                            child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(decoration: _getHeatmapDecor(v))),
                        ))),
                  ]),
                )),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('Less ', style: AppText.ui(12, color: AppColors.text2)),
              ...List.generate(
                  4,
                  (i) => Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(left: 3),
                        decoration: _getHeatmapDecor(i / 3.0, isLegend: true),
                      )),
              Text(' More', style: AppText.ui(12, color: AppColors.text2)),
            ]),
          ]),
        ),
      );

  BoxDecoration _getHeatmapDecor(double v, {bool isLegend = false}) {
    if (v <= 0) {
      return BoxDecoration(
        color: AppColors.borderSub,
        borderRadius: BorderRadius.circular(isLegend ? 2 : 3),
      );
    }

    int level;
    if (v <= 0.34) {
      level = 1;
    } else if (v <= 0.67) {
      level = 2;
    } else {
      level = 3;
    }

    Color? color;
    Border? border;
    List<BoxShadow>? shadows;

    switch (level) {
      case 1:
        // 1-7 shots: puste z ramką
        color = Colors.transparent;
        border = Border.all(
            color: AppColors.gold.withValues(alpha: 0.3), width: 0.8);
        break;
      case 2:
        // 8-15 shots: ramka i lekki zolty
        color = AppColors.gold.withValues(alpha: 0.35);
        border = Border.all(
            color: AppColors.gold.withValues(alpha: 0.45), width: 0.8);
        break;
      default: // Level 3: 15+ shots: zolty i poswiata
        color = AppColors.gold;
        border = Border.all(
            color: AppColors.gold.withValues(alpha: 0.8), width: 0.8);
        shadows = [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.5),
            blurRadius: 16,
            spreadRadius: 2.0,
          )
        ];
    }

    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(isLegend ? 2 : 3),
      border: border,
      boxShadow: shadows,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  5. QUOTE OF THE DAY  — at the bottom, changes daily
  // ══════════════════════════════════════════════════════════════════════════

  static const _quotes = [
    _Quote('"You miss 100% of the shots you don\'t take."', '— Wayne Gretzky'),
    _Quote('"Hard work beats talent when talent doesn\'t work hard."',
        '— Tim Notke'),
    _Quote(
        '"The only way to get better is to challenge yourself every single day."',
        '— LeBron James'),
    _Quote(
        '"Talent wins games, but teamwork and intelligence wins championships."',
        '— Michael Jordan'),
    _Quote(
        '"Excellence is not a singular act, but a habit. You are what you repeatedly do."',
        '— Shaquille O\'Neal'),
    _Quote('"I\'ve missed more than 9,000 shots. That\'s why I succeed."',
        '— Michael Jordan'),
    _Quote(
        '"Push yourself again and again. Don\'t give an inch until the final buzzer sounds."',
        '— Larry Bird'),
    _Quote(
        '"The strength of the team is each individual member. The strength of each member is the team."',
        '— Phil Jackson'),
    _Quote('"Be the hardest worker in the room. Every. Single. Day."',
        '— Kobe Bryant'),
    _Quote('"The more you sweat in practice, the less you bleed in the game."',
        '— Coach K'),
    _Quote(
        '"Great players are willing to give up their own personal glory for the good of the team."',
        '— Kareem Abdul-Jabbar'),
    _Quote('"If you\'re afraid to fail, you\'ll never succeed."',
        '— Charles Barkley'),
    _Quote(
        '"I can\'t relate to lazy people. We don\'t speak the same language."',
        '— Kobe Bryant'),
    _Quote(
        '"One man can be a crucial ingredient on a team, but one man cannot make a team."',
        '— Kareem Abdul-Jabbar'),
  ];

  Widget _quoteOfTheDay() {
    final dayIndex =
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    final quote = _quotes[dayIndex % _quotes.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(children: [
          Positioned(
            top: -12,
            right: -4,
            child: Text('"',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 100,
                  height: 1,
                  color: AppColors.gold.withValues(alpha: 0.08),
                  fontWeight: FontWeight.w900,
                )),
          ),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  quote.text,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    height: 1.5,
                    color: AppColors.text1,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 1.5,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(quote.author,
                        style: AppText.ui(12,
                            color: AppColors.text3, weight: FontWeight.w600)),
                  ],
                ),
              ]),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BOTTOM NAV
  // ══════════════════════════════════════════════════════════════════════════

  Widget _nav() {
    final items = [
      const _Nav(Icons.home_outlined, Icons.home_rounded, 'Home'),
      const _Nav(Icons.sports_basketball_outlined,
          Icons.sports_basketball_rounded, 'Train'),
      const _Nav(Icons.show_chart_rounded, Icons.show_chart_rounded, 'Stats'),
      const _Nav(Icons.history_rounded, Icons.history_rounded, 'History'),
      const _Nav(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];
    return Container(
      height: 76,
      decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
          children: List.generate(items.length, (i) {
        final active = _navIndex == i;
        return Expanded(
            child: GestureDetector(
          onTap: () => setState(() => _navIndex = i),
          behavior: HitTestBehavior.opaque,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(active ? items[i].activeIcon : items[i].icon,
                size: 22, color: active ? AppColors.gold : AppColors.text2),
            const SizedBox(height: 5),
            Text(items[i].label,
                style: AppText.ui(12,
                    weight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? AppColors.gold : AppColors.text2)),
          ]),
        ));
      })),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(t,
            style: AppText.ui(11,
                color: AppColors.text2,
                letterSpacing: 1.4,
                weight: FontWeight.w800)),
      );

  Widget _sessionsBarChart(List<int> wCnt, List<String> wLbl, List<int> mCnt, List<String> mLbl) {
    final data = _chartPeriod == 0 ? wCnt : mCnt;
    final labels = _chartPeriod == 0 ? wLbl : mLbl;
    final hasData = data.any((v) => v > 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(children: [
              Text('Sessions Count',
                  style: AppText.ui(14, weight: FontWeight.w600)),
              const Spacer(),
              Container(
                height: 30,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  _PeriodBtn('7D', _chartPeriod == 0,
                      () => setState(() => _chartPeriod = 0)),
                  _PeriodBtn('6M', _chartPeriod == 1,
                      () => setState(() => _chartPeriod = 1)),
                ]),
              ),
            ]),
          ),
          if (hasData) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(children: [
                Text(
                    '${data.reduce(math.max)} sessions peak',
                    style: AppText.ui(11, color: AppColors.gold)),
                const Spacer(),
              ]),
            ),
            SizedBox(
                height: 160,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: CustomPaint(
                      painter: _BarChartPainter(data: data, labels: labels),
                      size: Size.infinite),
                )),
          ] else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: Text('No data yet',
                      style: AppText.ui(13, color: AppColors.text3))),
            ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LOG CARD
// ══════════════════════════════════════════════════════════════════════════════

class _LogCard extends StatelessWidget {
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color? bgColor;
  final Color borderColor;
  final Color? shadowColor;
  final IconData watermarkIcon;
  final double watermarkAlpha;
  final Widget iconWidget;
  final String title, subtitle;
  final Color titleColor, subtitleColor;

  const _LogCard({
    required this.onTap,
    this.gradient,
    this.bgColor,
    this.borderColor = Colors.transparent,
    this.shadowColor,
    required this.watermarkIcon,
    this.watermarkAlpha = 0.14,
    required this.iconWidget,
    required this.title,
    required this.titleColor,
    required this.subtitle,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: gradient,
            color: bgColor,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(18),
            boxShadow: shadowColor != null
                ? [
                    BoxShadow(
                        color: shadowColor!,
                        blurRadius: 18,
                        offset: const Offset(0, 6))
                  ]
                : null,
          ),
          child: Stack(children: [
            Positioned(
                right: -16,
                bottom: -16,
                child: Icon(watermarkIcon,
                    size: 90,
                    color: Colors.white.withValues(alpha: watermarkAlpha))),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  const SizedBox(height: 20),
                  Text(title,
                      style: AppText.ui(14,
                          weight: FontWeight.w800, color: titleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: AppText.ui(11, color: subtitleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  LINE CHART PAINTER
// ══════════════════════════════════════════════════════════════════════════════

class _BarChartPainter extends CustomPainter {
  final List<int> data;
  final List<String> labels;
  const _BarChartPainter({required this.data, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const padL = 32.0, padR = 16.0, padB = 24.0, padT = 12.0;
    final cW = size.width - padL - padR;
    final cH = size.height - padB - padT;
    final maxV = data.reduce(math.max).toDouble();
    if (maxV == 0) return;

    double dx(int i) => padL + i * cW / (data.length - 1);
    
    final guide = Paint()
      ..color = AppColors.borderSub
      ..strokeWidth = 1;

    // Draw horizontal guides
    for (int g = 0; g <= 4; g++) {
      final y = padT + g * cH / 4;
      canvas.drawLine(Offset(padL, y), Offset(size.width, y), guide);
      final val = (maxV - g * maxV / 4).round();
      final tp = TextPainter(
        text: TextSpan(
            text: '$val',
            style: const TextStyle(color: AppColors.text3, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final barPaint = Paint()..color = AppColors.gold;
    final barW = cW / (data.length * 2);

    for (int i = 0; i < data.length; i++) {
        final val = data[i].toDouble();
        final h = (val / maxV) * cH;
        final x = dx(i);
        final rect = Rect.fromLTWH(x - barW / 2, padT + cH - h, barW, h);
        final rRect = RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
        );

        barPaint.shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.gold.withValues(alpha: 0.7),
            AppColors.gold,
          ],
        ).createShader(rect);

        canvas.drawRRect(rRect, barPaint);

        final isLast = i == data.length - 1;
        final tp = TextPainter(
            text: TextSpan(
                text: labels[i],
                style: TextStyle(
                    color: isLast ? AppColors.gold : AppColors.text3,
                    fontSize: 10,
                    fontWeight: isLast ? FontWeight.w700 : FontWeight.w400)),
            textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, size.height - padB + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) => old.data != data;
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  const _LineChartPainter({required this.data, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const padL = 32.0, padB = 24.0, padT = 12.0;
    final cW = size.width - padL;
    final cH = size.height - padB - padT;
    final minV = (data.reduce(math.min) - 0.05).clamp(0.0, 1.0);
    final maxV = (data.reduce(math.max) + 0.05).clamp(0.0, 1.0);
    final range = maxV - minV;

    double dx(int i) => padL + i * cW / (data.length - 1);
    double dy(double v) => padT + (1 - (v - minV) / range) * cH;

    final guide = Paint()
      ..color = AppColors.borderSub
      ..strokeWidth = 1;
    for (int g = 0; g <= 4; g++) {
      final y = padT + g * cH / 4;
      canvas.drawLine(Offset(padL, y), Offset(size.width, y), guide);
      final tp = TextPainter(
        text: TextSpan(
            text: '${((maxV - g * range / 4) * 100).round()}',
            style: const TextStyle(color: AppColors.text3, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    Path buildPath() {
      final p = Path()..moveTo(dx(0), dy(data[0]));
      for (int i = 1; i < data.length; i++) {
        final mid = (dx(i - 1) + dx(i)) / 2;
        p.cubicTo(mid, dy(data[i - 1]), mid, dy(data[i]), dx(i), dy(data[i]));
      }
      return p;
    }

    final area = buildPath()
      ..lineTo(dx(data.length - 1), padT + cH)
      ..lineTo(dx(0), padT + cH)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.gold.withValues(alpha: 0.22),
              AppColors.gold.withValues(alpha: 0)
            ],
          ).createShader(Rect.fromLTWH(0, padT, size.width, cH)));

    final line = buildPath();
    canvas.drawPath(
        line,
        Paint()
          ..color = AppColors.gold.withValues(alpha: 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawPath(
        line,
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true);

    for (int i = 0; i < data.length; i++) {
      final isLast = i == data.length - 1;
      if (isLast) {
        canvas.drawCircle(
            Offset(dx(i), dy(data[i])), 5, Paint()..color = AppColors.bg);
        canvas.drawCircle(
            Offset(dx(i), dy(data[i])),
            5,
            Paint()
              ..color = AppColors.gold
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      } else {
        canvas.drawCircle(Offset(dx(i), dy(data[i])), 3.5,
            Paint()..color = AppColors.gold.withValues(alpha: 0.6));
      }
      final tp = TextPainter(
        text: TextSpan(
            text: labels[i],
            style: TextStyle(
                color: isLast ? AppColors.gold : AppColors.text3,
                fontSize: 10,
                fontWeight: isLast ? FontWeight.w700 : FontWeight.w400)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx(i) - tp.width / 2, size.height - padB + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => old.data != data;
}

// ══════════════════════════════════════════════════════════════════════════════
//  DATA MODELS & SMALL WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _Quote {
  final String text, author;
  const _Quote(this.text, this.author);
}

class _PeriodBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PeriodBtn(this.label, this.active, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
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

class _Nav {
  final IconData icon, activeIcon;
  final String label;
  const _Nav(this.icon, this.activeIcon, this.label);
}
