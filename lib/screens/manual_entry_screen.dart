import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../widgets/basketball_court_map.dart';
import '../models/session.dart';
import '../models/shot.dart';
import '../services/session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

// ═════════════════════════════════════════════════════════════════════════════
//  MANUAL ENTRY SCREEN
//  Log a past session: pick location → enter made / attempts → save.
//  Designed to fit any standard mobile screen with NO scrolling.
// ═════════════════════════════════════════════════════════════════════════════

class ManualEntryScreen extends StatefulWidget {
  final Session? initialSession;
  const ManualEntryScreen({super.key, this.initialSession});
  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen>
    with TickerProviderStateMixin {
  // ── state ─────────────────────────────────────────────────────────────────
  bool _positionMode = true;
  String _selectedId = 'free_throw';
  int _made = 0;
  int _swishes = 0;
  int _misses = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialSession != null) {
      final s = widget.initialSession!;
      _positionMode = s.mode == 'position';
      _selectedId = s.selectionId;
      _made = s.made;
      _swishes = s.swishes;
      _misses = s.attempts - s.made;
    }
  }

  static const _zones = [
    RangeZone('layup', 'Layup', 0),
    RangeZone('close', 'Close Shot', 1),
    RangeZone('mid', 'Mid Range', 2),
    RangeZone('three', 'Three Point', 3),
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

  // ── animations ────────────────────────────────────────────────────────────
  late final AnimationController _fadeIn = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400))
    ..forward();

  late final AnimationController _madeBounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final AnimationController _swishBounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final AnimationController _attBounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));

  late final Animation<double> _madeScale = _bounceAnim(_madeBounce);
  late final Animation<double> _swishScale = _bounceAnim(_swishBounce);
  late final Animation<double> _attScale = _bounceAnim(_attBounce);

  static Animation<double> _bounceAnim(AnimationController c) => TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.20), weight: 35),
        TweenSequenceItem(tween: Tween(begin: 1.20, end: 0.95), weight: 35),
        TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
      ]).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));

  // ── computed ──────────────────────────────────────────────────────────────
  int get _totalMade => _made + _swishes;
  int get _attempts => _totalMade + _misses;
  double get _pct => _attempts == 0 ? 0 : _totalMade / _attempts;
  String get _pctStr => _attempts == 0 ? '—' : '${(_pct * 100).round()}%';

  Color get _pctColor {
    if (_attempts == 0) return AppColors.text3;
    if (_pct >= 0.70) return AppColors.green;
    if (_pct >= 0.50) return AppColors.gold;
    return AppColors.red;
  }

  String get _selectedLabel {
    if (_positionMode) {
      final i = _spotIds.indexOf(_selectedId);
      return i >= 0 ? _spotLabels[i] : '';
    }
    return _zones.firstWhere((z) => z.id == _selectedId).label;
  }

  // ── actions ───────────────────────────────────────────────────────────────
  void _bumpMade(int d) {
    final v = (_made + d).clamp(0, 9999);
    if (v == _made) return;
    HapticFeedback.selectionClick();
    setState(() => _made = v);
    _madeBounce.forward(from: 0);
  }

  void _bumpSwishes(int d) {
    final v = (_swishes + d).clamp(0, 9999);
    if (v == _swishes) return;
    HapticFeedback.selectionClick();
    setState(() => _swishes = v);
    _swishBounce.forward(from: 0);
  }

  void _bumpMisses(int d) {
    final v = (_misses + d).clamp(0, 9999);
    if (v == _misses) return;
    HapticFeedback.selectionClick();
    setState(() => _misses = v);
    _attBounce.forward(from: 0);
  }

  void _save() async {
    if (_attempts == 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Add at least 1 attempt', style: AppText.ui(13)),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ));
      return;
    }
    HapticFeedback.heavyImpact();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final session = Session(
        id: widget.initialSession?.id,
        userId: user.id,
        type: 'manual',
        mode: _positionMode ? 'position' : 'range',
        selectionId: _selectedId,
        selectionLabel: _selectedLabel,
        targetShots: _attempts,
        made: _totalMade,
        swishes: _swishes,
        attempts: _attempts,
        bestStreak: 0,
        elapsedSeconds: 0,
        createdAt: widget.initialSession?.createdAt,
      );

      final shots = <Shot>[];
      int idx = 0;

      for (int i = 0; i < _swishes; i++) {
        shots.add(Shot(
            sessionId: session.id ?? '',
            userId: user.id,
            orderIdx: idx++,
            isMake: true,
            isSwish: true));
      }
      for (int i = 0; i < _made; i++) {
        shots.add(Shot(
            sessionId: session.id ?? '',
            userId: user.id,
            orderIdx: idx++,
            isMake: true,
            isSwish: false));
      }
      for (int i = 0; i < _misses; i++) {
        shots.add(Shot(
            sessionId: session.id ?? '',
            userId: user.id,
            orderIdx: idx++,
            isMake: false,
            isSwish: false));
      }

      if (widget.initialSession != null) {
        await SessionService().updateManualSession(session, shots);
      } else {
        await SessionService().saveSessionData(session, shots);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save session: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    _madeBounce.dispose();
    _swishBounce.dispose();
    _attBounce.dispose();
    super.dispose();
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeIn, curve: Curves.easeOut),
        child: SafeArea(
          child: Column(children: [
            // ── header ──────────────────────────────────────────────────────
            _header(),
            const SizedBox(height: 14),

            // ── mode toggle + selected hint ─────────────────────────────────
            _modeRow(),
            const SizedBox(height: 14),

            // ── live stats strip ────────────────────────────────────────────
            _statsStrip(),
            const SizedBox(height: 14),

            // ── court (fixed height, always visible) ────────────────────────
            _court(),
            const SizedBox(height: 16),

            // ── counters ────────────────────────────────────────────────────
            _counters(),
            const SizedBox(height: 16),

            // ── save button ─────────────────────────────────────────────────
            _saveBar(),
          ]),
        ),
      ),
    );
  }

  // ── header ────────────────────────────────────────────────────────────────

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(children: [
          _IconBtn(
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MANUAL ENTRY',
                style: AppText.ui(11,
                    color: AppColors.text2,
                    letterSpacing: 1.4,
                    weight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Log a past session',
                style: AppText.ui(15, weight: FontWeight.w700)),
          ]),
        ]),
      );

  // ── live stats strip ──────────────────────────────────────────────────────
  // Single compact row: accuracy % · made · missed · grade
  Widget _statsStrip() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
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
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CURRENT ZONE',
                            style: AppText.ui(10,
                                color: AppColors.gold,
                                letterSpacing: 2.0,
                                weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                              _selectedLabel.isEmpty ? '—' : _selectedLabel,
                              style:
                                  AppText.display(28, color: AppColors.text1)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _gradeBadge(_pct),
                ],
              ),
              const SizedBox(height: 24),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: [
                    _statItem('ACCURACY', _pctStr, _pctColor),
                    const SizedBox(width: 32),
                    _statItem('MAKES', '$_totalMade', AppColors.text1),
                    const SizedBox(width: 32),
                    _statItem('MISSES', '$_misses', AppColors.text2),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _gradeBadge(double pct) {
    String grade = 'D';
    Color color = AppColors.red;

    if (_attempts == 0) {
      grade = '·';
      color = AppColors.text3;
    } else if (pct >= 0.85) {
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
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Center(
        child: Text(grade, style: AppText.display(24, color: color)),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.ui(9, color: AppColors.text3, letterSpacing: 1.0)),
        const SizedBox(height: 2),
        Text(value, style: AppText.display(24, color: color)),
      ],
    );
  }

  // ── mode row ──────────────────────────────────────────────────────────────

  Widget _modeRow() => Padding(
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
            _ModeTab('Position', _positionMode, () {
              HapticFeedback.selectionClick();
              setState(() {
                _positionMode = true;
                _selectedId = 'free_throw';
              });
            }),
            _ModeTab('Range', !_positionMode, () {
              HapticFeedback.selectionClick();
              setState(() {
                _positionMode = false;
                _selectedId = 'mid';
              });
            }),
          ]),
        ),
      );

  // ── court ─────────────────────────────────────────────────────────────────

  Widget _court() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: BasketballCourtMap(
          mode: _positionMode ? CourtMapMode.setup : CourtMapMode.range,
          selectedId: _selectedId,
          onSpotTap: (id) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedId = id;
            });
          },
          spots: _positionMode
              ? _spotIds
                  .map((id) => MapSpotData(
                      id: id, label: _spotLabels[_spotIds.indexOf(id)]))
                  .toList()
              : const [],
          zones: _zones.map((z) => RangeZone(z.id, z.label, z.tier)).toList(),
        ),
      );

  // ── counters ──────────────────────────────────────────────────────────────
  // Three side-by-side counter cards

  Widget _counters() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Expanded(
              child: _CounterCard(
            label: 'MADE',
            value: _made,
            scaleAnim: _madeScale,
            color: AppColors.green,
            onDec: () => _bumpMade(-1),
            onInc: () => _bumpMade(1),
            onDecLong: () => _bumpMade(-5),
            onIncLong: () => _bumpMade(5),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: _CounterCard(
            label: 'SWISH',
            value: _swishes,
            scaleAnim: _swishScale,
            color: AppColors.gold,
            onDec: () => _bumpSwishes(-1),
            onInc: () => _bumpSwishes(1),
            onDecLong: () => _bumpSwishes(-5),
            onIncLong: () => _bumpSwishes(5),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: _CounterCard(
            label: 'MISSES',
            value: _misses,
            scaleAnim: _attScale,
            color: AppColors.red,
            onDec: () => _bumpMisses(-1),
            onInc: () => _bumpMisses(1),
            onDecLong: () => _bumpMisses(-5),
            onIncLong: () => _bumpMisses(5),
          )),
        ]),
      );

  // ── save bar ──────────────────────────────────────────────────────────────

  Widget _saveBar() {
    final ok = _attempts > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: GestureDetector(
        onTap: ok ? _save : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 50,
          decoration: BoxDecoration(
            color: ok ? AppColors.gold : AppColors.surface,
            border: Border.all(color: ok ? AppColors.gold : AppColors.border),
            borderRadius: BorderRadius.circular(13),
            boxShadow: ok
                ? [
                    BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Center(
            child: Text('Save Session',
                style: AppText.ui(15,
                    weight: FontWeight.w700,
                    color: ok ? AppColors.bg : AppColors.text3)),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  COUNTER CARD  — compact side-by-side counter with animated number
// ═════════════════════════════════════════════════════════════════════════════

class _CounterCard extends StatelessWidget {
  final String label;
  final int value;
  final Animation<double> scaleAnim;
  final Color color;
  final VoidCallback onDec, onInc, onDecLong, onIncLong;

  const _CounterCard({
    required this.label,
    required this.value,
    required this.scaleAnim,
    required this.color,
    required this.onDec,
    required this.onInc,
    required this.onDecLong,
    required this.onIncLong,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style: AppText.ui(9,
                  color: AppColors.text3,
                  letterSpacing: 1.4,
                  weight: FontWeight.w700)),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _RoundBtn(
            icon: Icons.remove_rounded,
            onTap: onDec,
            onLong: onDecLong,
            color: AppColors.bg,
            backgroundColor: color.withValues(alpha: 0.8),
            size: 28,
          ),
          const SizedBox(width: 6),
          AnimatedBuilder(
            animation: scaleAnim,
            builder: (_, __) => Transform.scale(
              scale: scaleAnim.value,
              child: SizedBox(
                width: 36,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: AppText.display(34, color: color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _RoundBtn(
            icon: Icons.add_rounded,
            onTap: onInc,
            onLong: onIncLong,
            color: AppColors.bg,
            backgroundColor: color,
            filled: true,
            size: 28,
          ),
        ]),
        const SizedBox(height: 6),
        Text('Hold ±5', style: AppText.ui(9, color: AppColors.text3)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _RoundBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap, onLong;
  final Color color;
  final Color? backgroundColor;
  final bool filled;
  final double size;
  const _RoundBtn({
    required this.icon,
    required this.onTap,
    required this.onLong,
    required this.color,
    this.backgroundColor,
    this.filled = false,
    this.size = 36,
  });
  @override
  State<_RoundBtn> createState() => _RoundBtnState();
}

class _RoundBtnState extends State<_RoundBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 100));
  late final Animation<double> _s = Tween(begin: 1.0, end: 0.84)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      onLongPress: () {
        widget.onLong();
        HapticFeedback.mediumImpact();
      },
      child: AnimatedBuilder(
        animation: _s,
        builder: (_, __) => Transform.scale(
          scale: _s.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.backgroundColor ??
                  (widget.filled
                      ? widget.color.withValues(alpha: 0.15)
                      : AppColors.bg),
              border: widget.backgroundColor != null
                  ? null
                  : Border.all(
                      color: widget.filled
                          ? widget.color.withValues(alpha: 0.40)
                          : AppColors.border,
                      width: 1.2,
                    ),
            ),
            child: Icon(widget.icon,
                size: widget.size * 0.61, color: widget.color),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
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
          child: Icon(icon, size: 18, color: AppColors.text2),
        ),
      );
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeTab(this.label, this.active, this.onTap);
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            height: double.infinity,
            decoration: BoxDecoration(
              color: active ? AppColors.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(label,
                  style: AppText.ui(13,
                      weight: FontWeight.w600,
                      color: active ? AppColors.bg : AppColors.text3)),
            ),
          ),
        ),
      );
}
