import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'session_detail_screen.dart';
import 'manual_session_detail_screen.dart';
import 'game_session_detail_screen.dart';
import 'session_setup_screen.dart';
import '../models/session.dart';
import '../models/shot.dart';
import '../services/session_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ═════════════════════════════════════════════════════════════════════════════

enum SessionType { live, manual, game }

class GameSessionData {
  final String modeId;
  final Map<String, dynamic> stats;
  const GameSessionData({required this.modeId, required this.stats});
}

class HistoryEntry {
  final String id;
  final SessionType type;
  final String title;
  final String subtitle;
  final DateTime date;
  final Duration elapsed;
  final Color color;
  final IconData icon;
  final int? made;
  final int? attempts;
  final List<bool>? shotLog;
  final HoopSession? hoopSession;
  final GameSessionData? gameData;

  const HistoryEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.elapsed,
    required this.color,
    required this.icon,
    this.made,
    this.attempts,
    this.shotLog,
    this.hoopSession,
    this.gameData,
  });

  double? get pct => (made != null && attempts != null && attempts! > 0)
      ? made! / attempts!
      : null;
  String get pctStr => pct != null ? '${(pct! * 100).round()}%' : '—';

  String get dateLabel {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}.${date.month}.${date.year}';
  }

  String get timeStr {
    if (elapsed.inSeconds == 0) return '—';
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static HistoryEntry fromSession(Session s) {
    SessionType type = SessionType.live;
    if (s.type == 'game') {
      type = SessionType.game;
    } else if (s.type == 'manual') {
      type = SessionType.manual;
    }

    IconData icon = Icons.sports_basketball_rounded;
    Color color = AppColors.blue;
    String title = s.selectionLabel;
    String subtitle = s.mode;

    if (type == SessionType.game) {
      icon = Icons.sports_esports_rounded;
      color = AppColors.gold;
      title = s.selectionLabel.isNotEmpty
          ? s.selectionLabel
          : (s.gameModeId?.replaceAll('_', ' ').toUpperCase() ?? 'GAME');
      subtitle = 'Game · ${s.attempts} shots';
    } else if (type == SessionType.manual) {
      icon = Icons.edit_rounded;
      color = AppColors.green;
      title = s.selectionLabel;
      subtitle = '${s.mode} · Manual entry';
    } else {
      icon = Icons.show_chart_rounded;
      color = AppColors.blue;
      subtitle = '${s.mode} · ${s.attempts} shots';
    }

    HoopSession? hoopSession;
    if (type != SessionType.game) {
      // Sort shots by order_idx so the timeline is chronological
      List<Shot>? sortedShots = s.shots?.toList();
      if (sortedShots != null && sortedShots.isNotEmpty) {
        sortedShots.sort((a, b) => a.orderIdx.compareTo(b.orderIdx));
      }

      hoopSession = HoopSession(
        id: s.selectionId,
        mode: s.mode == 'position' ? SessionMode.position : SessionMode.range,
        zone: s.selectionLabel,
        dateLabel: '',
        date: s.createdAt ?? DateTime.now(),
        made: s.made,
        attempts: s.attempts,
        color: color,
        isLive: type == SessionType.live,
        elapsed: Duration(seconds: s.elapsedSeconds),
        shotHistory: sortedShots?.map((e) => e.isMake).toList(),
        maxStreak: s.bestStreak,
        swishPct: s.attempts > 0 ? (s.swishes * 100 ~/ s.attempts) : 0,
        globalAvgPct: 45,
      );
    }

    GameSessionData? gameData;
    if (type == SessionType.game && s.gameData != null) {
      gameData =
          GameSessionData(modeId: s.gameModeId ?? '', stats: s.gameData!);
    }

    return HistoryEntry(
      id: s.id ?? '',
      type: type,
      title: title,
      subtitle: subtitle,
      date: s.createdAt ?? DateTime.now(),
      elapsed: Duration(seconds: s.elapsedSeconds),
      color: color,
      icon: icon,
      made: s.made,
      attempts: s.attempts,
      shotLog: s.shots?.map((e) => e.isMake).toList(),
      hoopSession: hoopSession,
      gameData: gameData,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HISTORY SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500))
    ..forward();

  int _filterIdx = 0;
  static const _filters = ['All', 'Training', 'Games', 'Manual'];
  List<HistoryEntry>? _history;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final sessions = await SessionService().getHistory();
      if (mounted) {
        setState(() {
          _history = sessions.map((s) => HistoryEntry.fromSession(s)).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<HistoryEntry> get _filtered {
    if (_history == null) return [];
    switch (_filterIdx) {
      case 1:
        return _history!.where((e) => e.type == SessionType.live).toList();
      case 2:
        return _history!.where((e) => e.type == SessionType.game).toList();
      case 3:
        return _history!.where((e) => e.type == SessionType.manual).toList();
      default:
        return _history!;
    }
  }

  // group by date label preserving order
  List<MapEntry<String, List<HistoryEntry>>> get _grouped {
    final map = <String, List<HistoryEntry>>{};
    for (final e in _filtered) {
      map.putIfAbsent(e.dateLabel, () => []).add(e);
    }
    return map.entries.toList();
  }

  int get _totalMade => _history?.fold(0, (s, e) => s! + (e.made ?? 0)) ?? 0;
  int get _totalSessions => _history?.length ?? 0;

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
          _header(),
          const SizedBox(height: 4),
          _filterRow(),
          const SizedBox(height: 4),
          _summaryStrip(),
          Expanded(child: _body()),
        ])),
      ),
    );
  }

  // ── header ────────────────────────────────────────────────────────────────

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HISTORY',
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.8,
                    weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('All Sessions',
                style: AppText.ui(24, weight: FontWeight.w800)),
          ]),
          const Spacer(),
          // Aggregate pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.sports_basketball_rounded,
                  size: 13, color: AppColors.gold),
              const SizedBox(width: 6),
              Text('$_totalMade made',
                  style: AppText.ui(12,
                      weight: FontWeight.w600, color: AppColors.text2)),
              Container(
                  width: 1,
                  height: 14,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 8)),
              Text('$_totalSessions sessions',
                  style: AppText.ui(12,
                      weight: FontWeight.w600, color: AppColors.text2)),
            ]),
          ),
        ]),
      );

  // ── filter row ────────────────────────────────────────────────────────────

  Widget _filterRow() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: Row(
          children: List.generate(_filters.length, (i) {
            final on = _filterIdx == i;
            final isLast = i == _filters.length - 1;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _filterIdx = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  margin: EdgeInsets.only(right: isLast ? 0 : 8),
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? AppColors.gold : AppColors.surface,
                    border: Border.all(
                      color: on ? AppColors.gold : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _filters[i],
                    style: AppText.ui(
                      11,
                      weight: FontWeight.w600,
                      color: on ? AppColors.bg : AppColors.text2,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );

  // ── summary strip ─────────────────────────────────────────────────────────

  Widget _summaryStrip() {
    final live = _history?.where((e) => e.type == SessionType.live).length ?? 0;
    final games =
        _history?.where((e) => e.type == SessionType.game).length ?? 0;
    final manual =
        _history?.where((e) => e.type == SessionType.manual).length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.borderSub),
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _stripStat('$live', 'Training', AppColors.blue),
          Container(width: 1, height: 28, color: AppColors.borderSub),
          _stripStat('$games', 'Games', AppColors.gold),
          Container(width: 1, height: 28, color: AppColors.borderSub),
          _stripStat('$manual', 'Manual', AppColors.green),
        ]),
      ),
    );
  }

  Widget _stripStat(String v, String l, Color c) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
        const SizedBox(width: 6),
        Text(v, style: AppText.ui(14, weight: FontWeight.w700, color: c)),
        const SizedBox(width: 4),
        Text(l, style: AppText.ui(12, color: AppColors.text2)),
      ]);

  // ── body ──────────────────────────────────────────────────────────────────

  Widget _body() {
    if (_error != null) {
      return Center(
          child: Text('Error loading history: $_error',
              style: AppText.ui(14, color: AppColors.red)));
    }
    if (_history == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }

    final groups = _grouped;
    if (groups.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.history_rounded, size: 44, color: AppColors.text3),
        const SizedBox(height: 12),
        Text('No sessions yet',
            style: AppText.ui(16,
                color: AppColors.text2, weight: FontWeight.w600)),
        Text('Start training to see history here',
            style: AppText.ui(13, color: AppColors.text3)),
      ]));
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
      itemCount: groups.length,
      itemBuilder: (ctx, gi) {
        final group = groups[gi];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Group header
          Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 10),
              child: Row(children: [
                Text(group.key,
                    style: AppText.ui(10,
                        color: AppColors.text3,
                        weight: FontWeight.w700,
                        letterSpacing: 1.0)),
                const SizedBox(width: 10),
                Expanded(
                    child: Container(height: 1, color: AppColors.borderSub)),
                const SizedBox(width: 10),
                Text('${group.value.length}',
                    style: AppText.ui(10, color: AppColors.text3)),
              ])),
          // Cards
          ...group.value.asMap().entries.map((en) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child:
                    _SessionCard(entry: en.value, onTap: () => _open(en.value)),
              )),
        ]);
      },
    );
  }

  // ── navigation ────────────────────────────────────────────────────────────

  void _open(HistoryEntry e) {
    HapticFeedback.mediumImpact();
    Widget screen;
    if (e.type == SessionType.game && e.gameData != null) {
      screen = GameSessionDetailScreen(entry: e);
    } else if (e.type == SessionType.manual && e.hoopSession != null) {
      screen = ManualSessionDetailScreen(session: e.hoopSession!);
    } else if (e.hoopSession != null) {
      // Live session — use existing SessionDetailScreen with a completed animation
      screen = _LiveWrapper(session: e.hoopSession!);
    } else {
      return;
    }
    Navigator.push(context, _slideUp(screen));
  }

  PageRoute _slideUp(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 360),
        transitionsBuilder: (_, anim, __, child) {
          final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
                      .animate(c),
              child: FadeTransition(opacity: c, child: child));
        },
      );
}

// ── Live session wrapper (provides completed animation) ───────────────────────

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

// ═════════════════════════════════════════════════════════════════════════════
//  SESSION CARD
// ═════════════════════════════════════════════════════════════════════════════

class _SessionCard extends StatefulWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;
  const _SessionCard({required this.entry, required this.onTap});
  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 80));
  late final Animation<double> _scale = Tween(begin: 1.0, end: 0.965)
      .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final pctColor = e.pct != null
        ? (e.pct! >= 0.70
            ? AppColors.green
            : e.pct! >= 0.50
                ? AppColors.gold
                : AppColors.red)
        : e.color;

    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
          animation: _scale,
          builder: (_, __) => Transform.scale(
                scale: _scale.value,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    // Icon block
                    Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: e.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                                color: e.color.withValues(alpha: 0.20))),
                        child: Icon(e.icon, color: e.color, size: 22)),
                    const SizedBox(width: 12),
                    // Text
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Flexible(
                                child: Text(e.title,
                                    style:
                                        AppText.ui(14, weight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 7),
                            _TypeBadge(e.type),
                          ]),
                          Text(e.subtitle,
                              style: AppText.ui(11, color: AppColors.text3),
                              overflow: TextOverflow.ellipsis),
                        ])),
                    const SizedBox(width: 10),
                    // Right stats
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(e.pctStr,
                              style: AppText.display(22, color: pctColor)),
                          if (e.made != null && e.attempts != null)
                            Text('${e.made}/${e.attempts}',
                                style: AppText.ui(10, color: AppColors.text3)),
                          const SizedBox(height: 5),
                          if (e.elapsed.inSeconds > 0)
                            Row(children: [
                              const Icon(Icons.timer_outlined,
                                  size: 10, color: AppColors.text3),
                              const SizedBox(width: 3),
                              Text(e.timeStr,
                                  style:
                                      AppText.ui(10, color: AppColors.text3)),
                            ])
                          else
                            const Icon(Icons.chevron_right_rounded,
                                size: 16, color: AppColors.text3),
                        ]),
                  ]),
                ),
              )),
    );
  }
}

// ── Type badge ────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final SessionType type;
  const _TypeBadge(this.type);
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      SessionType.live => ('LIVE', AppColors.blue),
      SessionType.manual => ('MANUAL', AppColors.green),
      SessionType.game => ('GAME', AppColors.gold),
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Text(label,
            style: AppText.ui(8,
                weight: FontWeight.w800, color: color, letterSpacing: 0.6)));
  }
}
