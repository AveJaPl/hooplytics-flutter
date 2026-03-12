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
import '../utils/performance.dart';
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
  final Session originalSession;

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
    required this.originalSession,
  });

  double? get pct => (made != null && attempts != null && attempts! > 0)
      ? made! / attempts!
      : null;
  String get pctStr => pct != null ? '${(pct! * 100).round()}%' : '—';

  String get selectionLabel => originalSession.selectionLabel;
  String get selectionId => originalSession.selectionId;

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(d.year, d.month, d.day);
    final diff = today.difference(thatDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7 && diff > 0) return '$diff d ago';
    return '${d.day}.${d.month}.${d.year}';
  }

  String get dateLabel => _formatDate(date);

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
      // Game mapping - align with train_screen.dart
      final gid = s.gameModeId;
      if (gid == 'three_point_contest') {
        icon = Icons.sports_basketball_rounded;
        color = const Color(0xFFD4A843);
      } else if (gid == 'duel') {
        icon = Icons.people_rounded;
        color = const Color(0xFF5E8FEF);
      } else if (gid == 'horse') {
        icon = Icons.emoji_events_rounded;
        color = const Color(0xFFAA5EEF);
      } else if (gid == 'beat_the_clock') {
        icon = Icons.timer_rounded;
        color = const Color(0xFFFF7A5C);
      } else if (gid == 'streak_mode') {
        icon = Icons.local_fire_department_rounded;
        color = const Color(0xFFFF5252);
      } else if (gid == 'hot_spot') {
        icon = Icons.location_on_rounded;
        color = const Color(0xFF3DD68C);
      } else if (gid == 'pressure_fts') {
        icon = Icons.lens_rounded;
        color = const Color(0xFF5E8FEF);
      } else if (gid == 'around_the_world') {
        icon = Icons.public_rounded;
        color = const Color(0xFF3DD68C);
      } else if (gid == 'mikan_drill') {
        icon = Icons.swap_horiz_rounded;
        color = const Color(0xFFD4A843);
      } else {
        icon = Icons.sports_esports_rounded;
        color = AppColors.gold;
      }

      title = s.selectionLabel.isNotEmpty
          ? s.selectionLabel
          : (s.gameModeId?.replaceAll('_', ' ').toUpperCase() ?? 'GAME');
      subtitle = 'Game · ${s.attempts} shots';
    } else {
      // Session mapping - Blue for Position, Green for Range
      if (s.mode == 'position') {
        icon = Icons.gps_fixed_rounded;
        color = AppColors.blue;
      } else {
        icon = Icons.radar_rounded;
        color = AppColors.green;
      }

      if (type == SessionType.manual) {
        title = s.selectionLabel;
        subtitle = '${s.mode} · Manual entry';
      } else {
        subtitle = '${s.mode} · ${s.attempts} shots';
      }
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
        dateLabel: _formatDate(s.createdAt ?? DateTime.now()),
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
      originalSession: s,
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

  String _typeFilter = 'All'; // All, Sessions, Games
  String _modeFilter = 'All'; // Sessions: Position, Range; Games: Game Title
  String _detailFilter = 'All'; // Sessions: Specific Zone/Spot
  String _dateFilter = 'All Time';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _sortOption = 'Newest'; // Newest, Oldest
  String _searchQuery = '';

  List<HistoryEntry>? _history;
  String? _error;

  void _setFilter(
      {String? type,
      String? mode,
      String? detail,
      String? date,
      DateTime? start,
      DateTime? end}) {
    setState(() {
      if (type != null) {
        _typeFilter = type;
        _modeFilter = 'All';
        _detailFilter = 'All';
      }
      if (mode != null) {
        _modeFilter = mode;
        _detailFilter = 'All';
      }
      if (detail != null) _detailFilter = detail;
      if (date != null) _dateFilter = date;
      if (start != null || end != null || date == 'All Time') {
        _filterStartDate = start;
        _filterEndDate = end;
      }
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
      _setFilter(
          date: '${date.day}.${date.month}.${date.year}',
          start: start,
          end: end);
    }
  }

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
    var list = _history!;

    // 1. Search Query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) {
        return e.title.toLowerCase().contains(q) ||
            e.subtitle.toLowerCase().contains(q) ||
            (e.hoopSession?.mode.toString().toLowerCase() ?? '').contains(q);
      }).toList();
    }

    // 2. Type Filter
    if (_typeFilter != 'All') {
      if (_typeFilter == 'Sessions') {
        list = list.where((e) => e.type != SessionType.game).toList();
      } else {
        list = list.where((e) => e.type == SessionType.game).toList();
      }
    }

    // 3. Mode/Sub-Type Filter
    if (_modeFilter != 'All') {
      if (_typeFilter == 'Sessions') {
        final mode = _modeFilter.toLowerCase();
        list = list.where((e) => e.originalSession.mode == mode).toList();
      } else if (_typeFilter == 'Games') {
        list = list.where((e) => e.title == _modeFilter).toList();
      }
    }

    // 4. Detail Filter
    if (_detailFilter != 'All') {
      if (_typeFilter == 'Sessions' && _modeFilter == 'Range') {
        // e.selectionId corresponds to zone mapping
        list = list
            .where((e) =>
                e.selectionLabel.toLowerCase() == _detailFilter.toLowerCase())
            .toList();
      } else if (_typeFilter == 'Sessions' && _modeFilter == 'Position') {
        list = list.where((e) => e.selectionLabel == _detailFilter).toList();
      }
    }

    // 4. Date Filter
    if (_filterStartDate != null) {
      list = list
          .where((e) =>
              e.date.isAfter(_filterStartDate!) ||
              e.date.isAtSameMomentAs(_filterStartDate!))
          .toList();
    }
    if (_filterEndDate != null) {
      list = list
          .where((e) =>
              e.date.isBefore(_filterEndDate!) ||
              e.date.isAtSameMomentAs(_filterEndDate!))
          .toList();
    }

    // 5. Sort
    final sorted = List<HistoryEntry>.from(list);
    if (_sortOption == 'Oldest') {
      sorted.sort((a, b) => a.date.compareTo(b.date));
    } else {
      sorted.sort((a, b) => b.date.compareTo(a.date));
    }

    return sorted;
  }

  // group by date label preserving order
  List<MapEntry<String, List<HistoryEntry>>> get _grouped {
    final list = _filtered;
    final map = <String, List<HistoryEntry>>{};
    for (final e in list) {
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
          const SizedBox(height: 16),
          _controlBar(),
          const SizedBox(height: 12),
          Expanded(child: _body()),
        ])),
      ),
    );
  }

  // ── control bar ───────────────────────────────────────────────────────────

  Widget _controlBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              // Search (50%)
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: AppText.ui(13, color: AppColors.text1),
                    cursorColor: AppColors.gold,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: AppText.ui(13, color: AppColors.text3),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: AppColors.text3),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Filter (25%)
              Expanded(
                flex: 1,
                child: _controlButton(
                  label: 'Filter',
                  icon: Icons.tune_rounded,
                  active: _typeFilter != 'All' ||
                      _modeFilter != 'All' ||
                      _detailFilter != 'All',
                  onTap: _openFilterDrawer,
                ),
              ),
              const SizedBox(width: 8),
              // Sort (25%)
              Expanded(
                flex: 1,
                child: _controlButton(
                  label: _sortOption,
                  icon: Icons.sort_rounded,
                  active: true,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _openFilterMenu('Sort By', ['Newest', 'Oldest'],
                        _sortOption, (v) => setState(() => _sortOption = v));
                  },
                ),
              ),
            ],
          ),
        ),
      );

  Widget _controlButton(
      {required String label,
      required IconData icon,
      required bool active,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.gold.withValues(alpha: 0.1)
              : AppColors.surface,
          border: Border.all(color: active ? AppColors.gold : AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14, color: active ? AppColors.gold : AppColors.text3),
            const SizedBox(width: 6),
            Text(label,
                style: AppText.ui(12,
                    weight: FontWeight.w600,
                    color: active ? AppColors.gold : AppColors.text1)),
          ],
        ),
      ),
    );
  }

  // ── filter drawer ─────────────────────────────────────────────────────────

  void _openFilterDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setDrawerState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              verticalDirection: VerticalDirection.up,
              children: [
                // Level 0: Execution Button (Anchored Bottom)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text('Show Results (${_filtered.length})',
                        style: AppText.ui(15, weight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 32),

                // Level 4: Date (Anchored Bottom-ish)
                _drawerGrid([
                  'All Time',
                  'Today',
                  'Past Week',
                  'Past Month',
                  'Past Year',
                  'Specific Date'
                ], _dateFilter, (v) {
                  if (v == 'Specific Date') {
                    _pickDate();
                    Navigator.pop(context);
                  } else {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    DateTime? start;
                    if (v == 'Today') {
                      start = today;
                    } else if (v == 'Past Week') {
                      start = today.subtract(const Duration(days: 7));
                    } else if (v == 'Past Month') {
                      start = DateTime(now.year, now.month - 1, now.day);
                    } else if (v == 'Past Year') {
                      start = DateTime(now.year - 1, now.month, now.day);
                    }
                    setDrawerState(() => _setFilter(date: v, start: start));
                  }
                }, key: const ValueKey('date_grid')),
                const SizedBox(height: 12),
                Row(children: [
                  Text('DATE',
                      style: AppText.ui(10,
                          color: AppColors.text3,
                          weight: FontWeight.w800,
                          letterSpacing: 1.2)),
                ]),
                const SizedBox(height: 24),

                // Level 1: Type Selection
                _drawerSegment(['All', 'Sessions', 'Games'], _typeFilter, (v) {
                  setDrawerState(() => _setFilter(type: v));
                }),
                const SizedBox(height: 12),
                Row(children: [
                  Text('TYPE',
                      style: AppText.ui(10,
                          color: AppColors.text3,
                          weight: FontWeight.w800,
                          letterSpacing: 1.2)),
                ]),

                // Level 2: Sub-Type (Starts emerging UPWARDS)
                AnimatedSize(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_typeFilter != 'All') ...[
                        const SizedBox(height: 24),
                        Row(children: [
                          Text(
                              _typeFilter == 'Sessions'
                                  ? 'TRACKING MODE'
                                  : 'GAME',
                              style: AppText.ui(10,
                                  color: AppColors.text3,
                                  weight: FontWeight.w800,
                                  letterSpacing: 1.2)),
                        ]),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: _typeFilter == 'Sessions'
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: _drawerSegment(
                                      ['All', 'Position', 'Range'], _modeFilter,
                                      (v) {
                                    setDrawerState(() => _setFilter(mode: v));
                                  }, key: const ValueKey('session_modes')),
                                )
                              : () {
                                  final titles = _history
                                          ?.where(
                                              (e) => e.type == SessionType.game)
                                          .map((e) => e.title)
                                          .toSet()
                                          .toList() ??
                                      [];
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: _drawerGrid(
                                        ['All', ...titles], _modeFilter, (v) {
                                      setDrawerState(() => _setFilter(mode: v));
                                    }, key: const ValueKey('game_titles')),
                                  );
                                }(),
                        ),
                      ],
                    ],
                  ),
                ),

                // Level 3: Detail (Emerges UPWARDS from mode)
                AnimatedSize(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_typeFilter == 'Sessions' &&
                          _modeFilter != 'All') ...[
                        const SizedBox(height: 24),
                        Row(children: [
                          Text(_modeFilter == 'Range' ? 'ZONE' : 'SPOT',
                              style: AppText.ui(10,
                                  color: AppColors.text3,
                                  weight: FontWeight.w800,
                                  letterSpacing: 1.2)),
                        ]),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: () {
                            List<String> details = ['All'];
                            if (_modeFilter == 'Range') {
                              details.addAll([
                                'Layup',
                                'Close Shot',
                                'Mid Range',
                                'Three Point'
                              ]);
                            } else {
                              details.addAll(_history
                                      ?.where((e) =>
                                          e.originalSession.mode == 'position')
                                      .map((e) => e.selectionLabel)
                                      .toSet()
                                      .toList() ??
                                  []);
                            }
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: _drawerGrid(details, _detailFilter, (v) {
                                setDrawerState(() => _setFilter(detail: v));
                              }, key: ValueKey('detail_grid_$_modeFilter')),
                            );
                          }(),
                        ),
                      ],
                    ],
                  ),
                ),

                // Top Header (Moves up as content grows)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filters',
                        style: AppText.ui(20, weight: FontWeight.w800)),
                    TextButton(
                      onPressed: () {
                        _setFilter(
                          type: 'All',
                          date: 'All Time',
                          start: null,
                          end: null,
                        );
                        setDrawerState(() {});
                      },
                      child: Text('Clear All',
                          style: AppText.ui(13,
                              color: AppColors.gold, weight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2))),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _drawerSegment(
      List<String> options, String current, Function(String) onSelect,
      {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: options.map((opt) {
          final sel = opt == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: sel ? AppColors.border : Colors.transparent),
                ),
                child: Text(opt,
                    style: AppText.ui(12,
                        weight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? AppColors.gold : AppColors.text2)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _drawerGrid(
      List<String> options, String current, Function(String) onSelect,
      {Key? key}) {
    return Wrap(
      key: key,
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: options.map((opt) {
        final sel = opt == current;
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AppColors.gold.withValues(alpha: 0.1) : AppColors.bg,
              border:
                  Border.all(color: sel ? AppColors.gold : AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(opt,
                style: AppText.ui(12,
                    weight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? AppColors.gold : AppColors.text2)),
          ),
        );
      }).toList(),
    );
  }

  // ── header ────────────────────────────────────────────────────────────────

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HISTORY',
                style: AppText.ui(11,
                    color: AppColors.text2,
                    letterSpacing: 1.4,
                    weight: FontWeight.w800)),
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

  void _openFilterMenu(String title, List<String> options, String current,
      Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(title,
                  style: AppText.ui(14,
                      weight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.text3)),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: options.map((opt) {
                    final selected = opt == current;
                    return ListTile(
                      onTap: () {
                        onSelect(opt);
                        Navigator.pop(context);
                      },
                      leading: Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: selected ? AppColors.gold : AppColors.text3,
                          size: 20),
                      title: Text(opt,
                          style: AppText.ui(16,
                              weight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? AppColors.text1
                                  : AppColors.text2)),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

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
                    style: AppText.ui(13,
                        color: AppColors.text3,
                        weight: FontWeight.w700,
                        letterSpacing: 1.0)),
                const SizedBox(width: 10),
                Expanded(
                    child: Container(height: 1, color: AppColors.borderSub)),
                const SizedBox(width: 10),
                Text('${group.value.length}',
                    style: AppText.ui(12, color: AppColors.text3)),
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
      screen = ManualSessionDetailScreen(
          session: e.hoopSession!, originalSession: e.originalSession);
    } else if (e.hoopSession != null) {
      // Live session — use existing SessionDetailScreen with a completed animation
      screen = _LiveWrapper(
          session: e.hoopSession!, originalSession: e.originalSession);
    } else {
      return;
    }
    Navigator.push(context, _slideUp(screen)).then((_) => _loadHistory());
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
  final Session originalSession;
  const _LiveWrapper({required this.session, required this.originalSession});
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
  Widget build(BuildContext context) => SessionDetailScreen(
      session: widget.session,
      animation: _c,
      originalSession: widget.originalSession);
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
    final pctColor =
        e.pct != null ? PerformanceGuide.colorFor(e.pct!) : e.color;

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
                            _TypeBadge(e),
                          ]),
                          Text(e.subtitle,
                              style: AppText.ui(12, color: AppColors.text2),
                              overflow: TextOverflow.ellipsis),
                        ])),
                    const SizedBox(width: 10),
                    // Right stats
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(e.pctStr,
                              style: AppText.display(28, color: pctColor)),
                        ]),
                  ]),
                ),
              )),
    );
  }
}

// ── Type badge ────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final HistoryEntry entry;
  const _TypeBadge(this.entry);
  @override
  Widget build(BuildContext context) {
    final label = switch (entry.type) {
      SessionType.live => 'LIVE',
      SessionType.manual => 'MANUAL',
      SessionType.game => 'GAME',
    };
    final color = entry.color;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Text(label,
            style: AppText.ui(10,
                weight: FontWeight.w800, color: color, letterSpacing: 0.6)));
  }
}
