import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'session_setup_screen.dart';
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
  const ManualEntryScreen({super.key});
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
  int _attempts = 0;

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
  double get _pct => _attempts == 0 ? 0 : _made / _attempts;
  int get _missed => _attempts - _made;
  String get _pctStr => _attempts == 0 ? '—' : '${(_pct * 100).round()}%';

  Color get _pctColor {
    if (_attempts == 0) return AppColors.text3;
    if (_pct >= 0.70) return AppColors.green;
    if (_pct >= 0.50) return AppColors.gold;
    return AppColors.red;
  }

  String get _grade {
    if (_attempts == 0) return '·';
    if (_pct >= 0.85) return 'S';
    if (_pct >= 0.75) return 'A';
    if (_pct >= 0.65) return 'B';
    if (_pct >= 0.50) return 'C';
    return 'D';
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
    setState(() {
      _made = v;
      if (_made > _attempts) _attempts = _made;
      if (_swishes > _made) _swishes = _made;
    });
    _madeBounce.forward(from: 0);
  }

  void _bumpSwishes(int d) {
    final v = (_swishes + d).clamp(0, _made); // Cannot exceed made shots
    if (v == _swishes) return;
    HapticFeedback.selectionClick();
    setState(() => _swishes = v);
    _swishBounce.forward(from: 0);
  }

  void _bumpAttempts(int d) {
    final v = (_attempts + d).clamp(_made, 9999);
    if (v == _attempts) return;
    HapticFeedback.selectionClick();
    setState(() => _attempts = v);
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

      // Create dummy manual session
      final session = Session(
        userId: user.id,
        type: 'manual',
        mode: _positionMode ? 'position' : 'range',
        selectionId: _selectedId,
        selectionLabel: _selectedLabel,
        targetShots: _attempts,
        made: _made,
        swishes: _swishes,
        attempts: _attempts,
        bestStreak: 0, // Not tracked in manual
        elapsedSeconds: 0,
      );

      // Create sequence of mock Shots based on counts
      // Order: Swishes (makes), Regular Makes, Misses
      final shots = <Shot>[];
      int idx = 0;

      for (int i = 0; i < _swishes; i++) {
        shots.add(Shot(
            sessionId: '',
            userId: user.id,
            orderIdx: idx++,
            isMake: true,
            isSwish: true));
      }
      for (int i = 0; i < (_made - _swishes); i++) {
        shots.add(Shot(
            sessionId: '',
            userId: user.id,
            orderIdx: idx++,
            isMake: true,
            isSwish: false));
      }
      for (int i = 0; i < _missed; i++) {
        shots.add(Shot(
            sessionId: '',
            userId: user.id,
            orderIdx: idx++,
            isMake: false,
            isSwish: false));
      }

      await SessionService().saveSessionData(session, shots);
      if (mounted) Navigator.of(context).pop();
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

            // ── live stats strip ────────────────────────────────────────────
            _statsStrip(),
            const SizedBox(height: 14),

            // ── mode toggle + selected hint ─────────────────────────────────
            _modeRow(),
            const SizedBox(height: 10),

            // ── court (fixed height, always visible) ────────────────────────
            _court(),
            const SizedBox(height: 16),

            // ── counters ────────────────────────────────────────────────────
            _counters(),

            const Spacer(),

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
          const Spacer(),
          Column(children: [
            Text('MANUAL ENTRY',
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.8,
                    weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Log a past session',
                style: AppText.ui(15, weight: FontWeight.w700)),
          ]),
          const Spacer(),
          const SizedBox(width: 38), // balance
        ]),
      );

  // ── live stats strip ──────────────────────────────────────────────────────
  // Single compact row: accuracy % · made · missed · grade
  Widget _statsStrip() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            // Accuracy
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ACCURACY',
                  style: AppText.ui(8,
                      color: AppColors.text3,
                      letterSpacing: 1.4,
                      weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(_pctStr, style: AppText.display(28, color: _pctColor)),
            ]),
            const SizedBox(width: 16),
            // Progress bar
            Expanded(
              child: Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _pct,
                    backgroundColor: AppColors.borderSub,
                    valueColor: AlwaysStoppedAnimation(_pctColor),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  _Strip('${_made}M', AppColors.green),
                  const SizedBox(width: 8),
                  _Strip('${_swishes}S', AppColors.gold),
                  const SizedBox(width: 8),
                  _Strip('${_missed}X', AppColors.red),
                ]),
              ]),
            ),
            const SizedBox(width: 14),
            // Grade badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _pctColor.withValues(alpha: 0.10),
                border: Border.all(
                    color: _pctColor.withValues(alpha: 0.32), width: 1.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: Text(_grade,
                      style: AppText.display(22, color: _pctColor))),
            ),
          ]),
        ),
      );

  // ── mode row ──────────────────────────────────────────────────────────────

  Widget _modeRow() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          // Toggle (Position / Range)
          Container(
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(9),
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
          const SizedBox(width: 12),
          // Selected hint
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _selectedId.isEmpty
                  ? const SizedBox.shrink()
                  : Row(key: ValueKey(_selectedId), children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: AppColors.gold)),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _selectedLabel,
                          style: AppText.ui(12,
                              weight: FontWeight.w700, color: AppColors.gold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
            ),
          ),
        ]),
      );

  // ── court ─────────────────────────────────────────────────────────────────

  Widget _court() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AspectRatio(
          aspectRatio: 1.05,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(builder: (_, c) {
              final geo = CourtGeo(c.maxWidth, c.maxHeight);
              return Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                    child: CustomPaint(painter: CourtLinePainter(geo))),
                if (!_positionMode)
                  Positioned.fill(
                      child: CustomPaint(
                          painter: RangeZonePainter(geo, _selectedId, _zones))),
                if (_positionMode)
                  ..._spotWidgets(geo)
                else
                  _rangeTapLayer(geo),
              ]);
            }),
          ),
        ),
      );

  List<Widget> _spotWidgets(CourtGeo geo) => geo.spots.map((s) {
        final px = (s.fx * geo.w).clamp(0.0, geo.w);
        final py = (s.fy * geo.h).clamp(0.0, geo.h);
        return Positioned(
          left: px - 28,
          top: py - 28,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedId = s.id);
            },
            child:
                CourtSpotWidget(selected: _selectedId == s.id, label: s.label),
          ),
        );
      }).toList();

  Widget _rangeTapLayer(CourtGeo geo) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final id = RangeZonePainter.getZoneAt(geo, d.localPosition);
            if (id != null) {
              HapticFeedback.selectionClick();
              setState(() => _selectedId = id);
            }
          },
          child: const SizedBox.expand(),
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
            label: 'ATTEMPT',
            value: _attempts,
            scaleAnim: _attScale,
            color: AppColors.text1,
            onDec: () => _bumpAttempts(-1),
            onInc: () => _bumpAttempts(1),
            onDecLong: () => _bumpAttempts(-5),
            onIncLong: () => _bumpAttempts(5),
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
      child: Row(children: [
        // Quick summary
        if (ok) ...[
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_selectedLabel.isEmpty ? '—' : _selectedLabel,
                  style: AppText.ui(13, weight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$_made made · $_attempts attempts · $_pctStr',
                  style: AppText.ui(11, color: AppColors.text3)),
            ]),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: GestureDetector(
            onTap: _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 50,
              decoration: BoxDecoration(
                color: ok ? AppColors.gold : AppColors.surface,
                border:
                    Border.all(color: ok ? AppColors.gold : AppColors.border),
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
                child: Text('Log Session',
                    style: AppText.ui(14,
                        weight: FontWeight.w800,
                        color: ok ? AppColors.bg : AppColors.text3)),
              ),
            ),
          ),
        ),
      ]),
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
            color: color.withValues(alpha: 0.55),
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
            color: color,
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
  final bool filled;
  final double size;
  const _RoundBtn({
    required this.icon,
    required this.onTap,
    required this.onLong,
    required this.color,
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
              color: widget.filled
                  ? widget.color.withValues(alpha: 0.15)
                  : AppColors.bg,
              border: Border.all(
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

class _Strip extends StatelessWidget {
  final String text;
  final Color color;
  const _Strip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppText.ui(11, weight: FontWeight.w700, color: color),
        overflow: TextOverflow.ellipsis,
      );
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeTab(this.label, this.active, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: AppText.ui(12,
                  weight: FontWeight.w600,
                  color: active ? AppColors.bg : AppColors.text3)),
        ),
      );
}
