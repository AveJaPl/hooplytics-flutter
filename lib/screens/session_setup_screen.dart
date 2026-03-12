import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'session_tracking_screen.dart';
import '../services/session_service.dart';
import '../widgets/basketball_court_map.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  DATA TYPES
// ═════════════════════════════════════════════════════════════════════════════

enum SessionMode { position, range }

// ═════════════════════════════════════════════════════════════════════════════
//  SESSION SETUP SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({super.key});
  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 460));
  SessionMode _mode = SessionMode.position;
  String? _selectedId = 'free_throw';
  Map<String, dynamic>? _selectionStats;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _entry.forward();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (_selectedId == null) return;
    setState(() => _loadingStats = true);
    try {
      final stats =
          await SessionService().getSelectionStats(_selectedId!, _mode.name);
      if (mounted) {
        setState(() {
          _selectionStats = stats;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  void _select(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedId = id;
      _selectionStats = null;
    });
    _fetchStats();
  }

  final _zones = [
    const RangeZone('layup', 'Layup', 0),
    const RangeZone('close', 'Close Shot', 1),
    const RangeZone('mid', 'Mid Range', 2),
    const RangeZone('three', 'Three Point', 3),
  ];

  static const _spotIds = [
    'left_corner',
    'right_corner',
    'left_wing',
    'right_wing',
    'top_arc',
    'left_elbow',
    'right_elbow',
    'left_block',
    'right_block',
    'free_throw',
    'high_arc',
    'left_mid',
    'right_mid',
  ];
  static const _spotLabels = [
    'Left Corner',
    'Right Corner',
    'Left Wing',
    'Right Wing',
    'Top of Arc',
    'Left Elbow',
    'Right Elbow',
    'Left Block',
    'Right Block',
    'Free Throw',
    'High Arc',
    'Left Mid',
    'Right Mid',
  ];

  String get _label {
    if (_selectedId == null) return '';
    if (_mode == SessionMode.position) {
      final i = _spotIds.indexOf(_selectedId!);
      return i >= 0 ? _spotLabels[i] : '';
    }
    return _zones.firstWhere((z) => z.id == _selectedId).label;
  }

  void _modeToggleAction(SessionMode newMode) {
    HapticFeedback.selectionClick();
    setState(() {
      _mode = newMode;
      _selectedId = newMode == SessionMode.position ? 'free_throw' : 'mid';
      _selectionStats = null;
    });
    _fetchStats();
  }

  void _start() {
    if (_selectedId == null) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => SessionTrackingScreen(
        mode: _mode,
        selectionId: _selectedId!,
        selectionLabel: _label,
      ),
      transitionDuration: const Duration(milliseconds: 340),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: child),
    ));
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _entry, curve: Curves.easeOut),
        child: SafeArea(
          child: Column(children: [
            _topBar(),
            const SizedBox(height: 16),
            _modeToggle(),
            const SizedBox(height: 12),
            Expanded(
              child: Column(children: [
                Expanded(flex: 1, child: _statsSection()),
                Expanded(flex: 2, child: _court()),
              ]),
            ),
            _bottom(),
          ]),
        ),
      ),
    );
  }

  // ── top bar ──────────────────────────────────────────────────────────────────

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(children: [
          _SmallBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NEW SESSION',
                style: AppText.ui(11,
                    color: AppColors.text2,
                    letterSpacing: 1.4,
                    weight: FontWeight.w800)),
            const SizedBox(height: 1),
            Text('Select your shooting zone',
                style: AppText.ui(16, weight: FontWeight.w700)),
          ]),
        ]),
      );

  // ── mode toggle ───────────────────────────────────────────────────────────────

  Widget _modeToggle() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(children: [
            _Tab('Position', _mode == SessionMode.position,
                () => _modeToggleAction(SessionMode.position)),
            _Tab('Range', _mode == SessionMode.range,
                () => _modeToggleAction(SessionMode.range)),
          ]),
        ),
      );

  // ── hint row ─────────────────────────────────────────────────────────────────

  Widget _statsSection() {
    final stats = _selectionStats;
    final String label = _label;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: LayoutBuilder(builder: (context, constraints) {
        final isSmall = constraints.maxHeight < 160;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: (stats == null && !_loadingStats)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.touch_app_rounded,
                          color: AppColors.text3, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        _mode == SessionMode.position
                            ? 'Tap a spot on the court'
                            : 'Tap a zone to select it',
                        style: AppText.ui(13, color: AppColors.text3),
                      ),
                    ],
                  ),
                )
              : Container(
                  key: ValueKey('${label}_$_loadingStats'),
                  width: double.infinity,
                  padding: EdgeInsets.all(isSmall ? 18 : 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(isSmall ? 20 : 24),
                    border: Border.all(color: AppColors.border),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surface,
                        AppColors.surface.withValues(alpha: 0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: isSmall ? 16 : 20,
                        offset: Offset(0, isSmall ? 8 : 10),
                      ),
                    ],
                  ),
                  child: _loadingStats
                      ? const Center(
                          child:
                              CircularProgressIndicator(color: AppColors.gold))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('YOUR HISTORY',
                                          style: AppText.ui(11,
                                              color: AppColors.gold,
                                              letterSpacing: 1.5,
                                              weight: FontWeight.w800)),
                                      SizedBox(height: isSmall ? 2 : 4),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(label,
                                            style: AppText.display(
                                                isSmall ? 24 : 28,
                                                color: AppColors.text1)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _gradeBadge(
                                    stats!['attempts'] > 0
                                        ? stats['made'] / stats['attempts']
                                        : 0.0,
                                    isSmall),
                              ],
                            ),
                            if (isSmall)
                              const SizedBox(height: 12)
                            else
                              const Spacer(),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                children: [
                                  _statItem(
                                      'ACCURACY',
                                      '${stats['attempts'] > 0 ? (stats['made'] / stats['attempts'] * 100).round() : 0}%',
                                      _getPctColor(stats['attempts'] > 0
                                          ? stats['made'] / stats['attempts']
                                          : 0.0),
                                      isSmall),
                                  SizedBox(width: isSmall ? 24 : 32),
                                  _statItem('MAKES', '${stats['made']}',
                                      AppColors.text1, isSmall),
                                  SizedBox(width: isSmall ? 24 : 32),
                                  _statItem('ATTEMPTS', '${stats['attempts']}',
                                      AppColors.text2, isSmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
        );
      }),
    );
  }

  Widget _gradeBadge(double pct, bool isSmall) {
    String grade = 'D';
    Color color = AppColors.red;

    if (pct >= 0.85) {
      grade = 'A+';
      color = AppColors.green;
    } else if (pct >= 0.75) {
      grade = 'A';
      color = AppColors.green;
    } else if (pct >= 0.65) {
      grade = 'B';
      color = AppColors.gold;
    } else if (pct >= 0.55) {
      grade = 'C';
      color = AppColors.gold;
    }

    return Container(
      width: isSmall ? 48 : 54,
      height: isSmall ? 48 : 54,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
            color: color.withValues(alpha: 0.3), width: isSmall ? 1.5 : 2),
      ),
      child: Center(
        child: Text(grade,
            style: AppText.display(isSmall ? 20 : 24, color: color)),
      ),
    );
  }

  Color _getPctColor(double pct) {
    if (pct >= 0.75) return AppColors.green;
    if (pct >= 0.55) return AppColors.gold;
    return AppColors.red;
  }

  Widget _statItem(String label, String value, Color color, bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.ui(11,
                color: AppColors.text2,
                letterSpacing: 0.5,
                weight: FontWeight.w700)),
        SizedBox(height: isSmall ? 1 : 2),
        Text(value, style: AppText.display(isSmall ? 20 : 24, color: color)),
      ],
    );
  }

  // ── court ─────────────────────────────────────────────────────────────────────

  Widget _court() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: BasketballCourtMap(
          themeColor: AppColors.gold,
          mode: _mode == SessionMode.position
              ? CourtMapMode.setup
              : CourtMapMode.range,
          selectedId: _selectedId,
          onSpotTap: _select,
          spots: _mode == SessionMode.position
              ? const [
                  MapSpotData(id: 'left_corner', label: 'Left Corner'),
                  MapSpotData(id: 'right_corner', label: 'Right Corner'),
                  MapSpotData(id: 'left_wing', label: 'Left Wing'),
                  MapSpotData(id: 'right_wing', label: 'Right Wing'),
                  MapSpotData(id: 'top_arc', label: 'Top of Arc'),
                  MapSpotData(id: 'left_elbow', label: 'Left Elbow'),
                  MapSpotData(id: 'right_elbow', label: 'Right Elbow'),
                  MapSpotData(id: 'left_block', label: 'Left Block'),
                  MapSpotData(id: 'right_block', label: 'Right Block'),
                  MapSpotData(id: 'free_throw', label: 'Free Throw'),
                  MapSpotData(id: 'high_arc', label: 'High Arc'),
                  MapSpotData(id: 'left_mid', label: 'Left Mid'),
                  MapSpotData(id: 'right_mid', label: 'Right Mid'),
                ]
              : const [],
          zones: _zones.map((z) => RangeZone(z.id, z.label, z.tier)).toList(),
        ),
      );

  // ── bottom bar ────────────────────────────────────────────────────────────────

  Widget _bottom() {
    final active = _selectedId != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: GestureDetector(
        onTap: active ? _start : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 50,
          decoration: BoxDecoration(
            color: active ? AppColors.gold : AppColors.surface,
            border:
                Border.all(color: active ? AppColors.gold : AppColors.border),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: Text('Start Session',
                style: AppText.ui(15,
                    weight: FontWeight.w700,
                    color: active ? AppColors.bg : AppColors.text2)),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: AppColors.text2),
        ),
      );
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab(this.label, this.active, this.onTap);
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: double.infinity,
            decoration: BoxDecoration(
              color: active ? AppColors.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(label,
                  style: AppText.ui(13,
                      weight: FontWeight.w600,
                      color: active ? AppColors.bg : AppColors.text2)),
            ),
          ),
        ),
      );
}
