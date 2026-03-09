import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'session_tracking_screen.dart';
import '../services/session_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  DATA TYPES
// ═════════════════════════════════════════════════════════════════════════════

enum SessionMode { position, range }

class CourtSpot {
  final String id, label;
  final double fx, fy; // fractional position (0–1) within court widget
  const CourtSpot(this.id, this.label, this.fx, this.fy);
}

class RangeZone {
  final String id, label;
  final int tier; // 0=layup 1=close 2=mid 3=three
  const RangeZone(this.id, this.label, this.tier);
}

// ═════════════════════════════════════════════════════════════════════════════
//  COURT GEOMETRY  ← single source of truth, shared by all painters & screens
// ═════════════════════════════════════════════════════════════════════════════

class CourtGeo {
  final double w, h;
  CourtGeo(this.w, this.h);

  // ── court extent ────────────────────────────────────────────────────────────
  double get baseY => h - 18.0; // baseline sits 18 px from bottom

  // ── basket (FIBA: 1.575 m from baseline, court 15 m wide → 0.105) ──────────
  double get bx => w / 2;
  double get by => baseY - w * 0.105;

  // ── key / paint box (4.9 m wide → 4.9/15 = 0.327, half = 0.163) ───────────
  double get keyL => bx - w * 0.163;
  double get keyR => bx + w * 0.163;

  // ── free-throw line (5.8 m from baseline → 5.8/15 = 0.387) ────────────────
  double get ftY => baseY - w * 0.387;

  // ── free-throw circle radius (1.8 m → 1.8/15 = 0.120) ─────────────────────
  double get ftR => w * 0.120;

  // ── three-point arc (6.75 m radius → 6.75/15 = 0.450) ─────────────────────
  double get tpArcR => w * 0.450;

  // ── three-point corner x (6.6 m from centre → 0.440) ──────────────────────
  double get tpL => bx - w * 0.440;
  double get tpR => bx + w * 0.440;

  // ── derived arc angles (used by painter AND zone builder) ──────────────────
  // Angle at which the 3pt arc meets x = tpL  (above basket → negative angle)
  double get tpStartAngle {
    final cos = (tpL - bx) / tpArcR;
    return -math.acos(cos.clamp(-1.0, 1.0));
  }

  // Positive (clockwise in Flutter) sweep from left to right through top
  double get tpSweepAngle => -2.0 * tpStartAngle;

  // y at which the arc meets the corner straight line
  double get tpIntersectY => by + tpArcR * math.sin(tpStartAngle);

  // ── restricted-area (layup) radius ─────────────────────────────────────────
  double get raR => w * 0.083;

  // layup zone = rim circle (same as raR for visual, slightly bigger for tap)
  double get layupR => raR * 1.15;

  // ── position spots (coordinates derived from geometry above) ───────────────
  List<CourtSpot> get spots {
    // Push 3pt spots further from the line so they don't overlap it
    const radialPad = 0.044; // fraction of w
    final spotR = tpArcR + w * radialPad;
    const cornerXPad = 0.038; // extra outward nudge for corners

    arcFx(double dx) => (bx + dx * w) / w;
    arcFy(double absDx) {
      final px = absDx * w;
      if (px >= spotR) return by / h;
      return (by - math.sqrt(spotR * spotR - px * px)) / h;
    }

    const wingDx = 0.385;
    return [
      CourtSpot('left_corner', 'Left Corner', (tpL / w) - cornerXPad,
          (baseY - w * 0.045) / h),
      CourtSpot('right_corner', 'Right Corner', (tpR / w) + cornerXPad,
          (baseY - w * 0.045) / h),
      CourtSpot('left_wing', 'Left Wing', arcFx(-wingDx), arcFy(wingDx)),
      CourtSpot('right_wing', 'Right Wing', arcFx(wingDx), arcFy(wingDx)),
      CourtSpot('top_arc', 'Top of Arc', 0.50, arcFy(0)),
      CourtSpot('left_elbow', 'Left Elbow', keyL / w, ftY / h),
      CourtSpot('right_elbow', 'Right Elbow', keyR / w, ftY / h),
      CourtSpot(
          'left_block', 'Left Block', (keyL / w) + 0.042, (by + w * 0.072) / h),
      CourtSpot('right_block', 'Right Block', (keyR / w) - 0.042,
          (by + w * 0.072) / h),
      CourtSpot('free_throw', 'Free Throw', 0.50, ftY / h),
      CourtSpot('high_arc', 'High Arc', 0.50, (ftY - w * 0.120) / h),
      CourtSpot(
          'left_mid', 'Left Mid', (keyL / w) - 0.115, (by - w * 0.135) / h),
      CourtSpot(
          'right_mid', 'Right Mid', (keyR / w) + 0.115, (by - w * 0.135) / h),
    ];
  }
}

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
                style: AppText.ui(9,
                    color: AppColors.text3,
                    letterSpacing: 1.8,
                    weight: FontWeight.w700)),
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
                                          style: AppText.ui(isSmall ? 9 : 10,
                                              color: AppColors.gold,
                                              letterSpacing: 2.0,
                                              weight: FontWeight.w700)),
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
            style: AppText.ui(isSmall ? 8 : 9,
                color: AppColors.text3, letterSpacing: isSmall ? 0.8 : 1.0)),
        SizedBox(height: isSmall ? 1 : 2),
        Text(value, style: AppText.display(isSmall ? 20 : 24, color: color)),
      ],
    );
  }

  // ── court ─────────────────────────────────────────────────────────────────────

  Widget _court() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AspectRatio(
          aspectRatio: 1.05,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: LayoutBuilder(builder: (_, c) {
              final geo = CourtGeo(c.maxWidth, c.maxHeight);
              return Stack(clipBehavior: Clip.none, children: [
                // 1. court lines
                Positioned.fill(
                    child: CustomPaint(painter: CourtLinePainter(geo))),
                // 2. zone fills (on top of lines, semi-transparent)
                if (_mode == SessionMode.range)
                  Positioned.fill(
                      child: CustomPaint(
                    painter: RangeZonePainter(geo, _selectedId, _zones),
                  )),
                // 3. spots OR range tap layer
                if (_mode == SessionMode.position)
                  ..._spotWidgets(geo)
                else
                  _zoneTapLayer(geo),
              ]);
            }),
          ),
        ),
      );

  List<Widget> _spotWidgets(CourtGeo geo) => geo.spots.map((s) {
        final px = s.fx * geo.w;
        final py = s.fy * geo.h;
        return Positioned(
          left: px - 28,
          top: py - 28,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _select(s.id),
            child:
                CourtSpotWidget(selected: _selectedId == s.id, label: s.label),
          ),
        );
      }).toList();

  Widget _zoneTapLayer(CourtGeo geo) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final id = RangeZonePainter.getZoneAt(geo, d.localPosition);
            if (id != null) _select(id);
          },
          child: const SizedBox.expand(),
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
                style: AppText.ui(14,
                    weight: FontWeight.w700,
                    color: active ? AppColors.bg : AppColors.text3)),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  RANGE ZONE PAINTER
//  Uses PathFillType.evenOdd for painting (guaranteed correct rendering).
//  Uses pure-math hit-testing (no Path.combine, always reliable).
// ═════════════════════════════════════════════════════════════════════════════

class RangeZonePainter extends CustomPainter {
  final CourtGeo g;
  final String? selectedId;
  final List<RangeZone> zones;

  const RangeZonePainter(this.g, this.selectedId, this.zones);

  // ── hit-test: which zone contains point p? ────────────────────────────────
  static String? getZoneAt(CourtGeo g, Offset p) {
    // Check if inside the 3pt area using the boundary path
    if (!buildThreePointArea(g).contains(p)) return 'three';

    // Inside 3pt area — check key box
    final inKey =
        p.dx >= g.keyL && p.dx <= g.keyR && p.dy >= g.ftY && p.dy <= g.baseY;
    if (!inKey) return 'mid';

    // Inside key box — check layup (rim) circle
    final dx = p.dx - g.bx;
    final dy = p.dy - g.by;
    final inLayup = dx * dx + dy * dy <= g.raR * g.raR;
    return inLayup ? 'layup' : 'close';
  }

  // ── path builders (evenOdd — correct for paint only) ─────────────────────
  static Path buildZonePath(CourtGeo g, int tier) {
    switch (tier) {
      case 0: // Layup — small rim circle
        return Path()
          ..addOval(Rect.fromCircle(center: Offset(g.bx, g.by), radius: g.raR));

      case 1: // Close Shot = paint box ("coffin") – rim circle
        return Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Rect.fromLTRB(g.keyL, g.ftY, g.keyR, g.baseY))
          ..addOval(Rect.fromCircle(center: Offset(g.bx, g.by), radius: g.raR));

      case 2: // Mid Range = 3pt area – key box
        return Path()
          ..fillType = PathFillType.evenOdd
          ..addPath(_tp(g), Offset.zero)
          ..addRect(Rect.fromLTRB(g.keyL, g.ftY, g.keyR, g.baseY));

      case 3: // Three Point = court rect – 3pt area
      default:
        return Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Rect.fromLTRB(0, 0, g.w, g.baseY))
          ..addPath(_tp(g), Offset.zero);
    }
  }

  /// Outline of the three-point region (corner straights + arc + baseline).
  static Path _tp(CourtGeo g) {
    final p = Path();
    p.moveTo(g.tpL, g.baseY);
    p.lineTo(g.tpL, g.tpIntersectY);
    p.arcTo(
      Rect.fromCircle(center: Offset(g.bx, g.by), radius: g.tpArcR),
      g.tpStartAngle,
      g.tpSweepAngle,
      false,
    );
    p.lineTo(g.tpR, g.baseY);
    p.close();
    return p;
  }

  /// Same path but public (used by ManualEntryScreen hit-testing).
  static Path buildThreePointArea(CourtGeo g) => _tp(g);

  // ── paint ─────────────────────────────────────────────────────────────────
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, g.w, g.baseY));

    // 1. Idle zones — outline + label only
    for (final z in zones) {
      if (z.id == selectedId) continue;
      final path = buildZonePath(g, z.tier);
      canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.text3.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..isAntiAlias = true);
      _label(canvas, z.label, _center(z.tier), false);
    }

    // 2. Selected zone — gold fill + gold stroke + pill label
    if (selectedId != null) {
      final z = zones.firstWhere((z) => z.id == selectedId,
          orElse: () => zones.first);
      final path = buildZonePath(g, z.tier);
      canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.gold.withValues(alpha: 0.16)
            ..style = PaintingStyle.fill);
      canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.gold.withValues(alpha: 0.88)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..isAntiAlias = true);
      _label(canvas, z.label, _center(z.tier), true);
    }

    canvas.restore();
  }

  Offset _center(int tier) {
    switch (tier) {
      case 0:
        return Offset(g.bx, g.by);
      case 1:
        return Offset(g.bx, g.ftY + (g.baseY - g.ftY) * 0.44);
      case 2:
        return Offset(g.bx, g.by - g.tpArcR * 0.82);
      case 3:
      default:
        return Offset(g.bx, g.by - g.tpArcR * 1.30);
    }
  }

  void _label(Canvas canvas, String text, Offset c, bool selected) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: selected
              ? AppColors.gold
              : AppColors.text2.withValues(alpha: 0.6),
          fontSize: selected ? 13.0 : 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    if (selected) {
      final r = Rect.fromCenter(
          center: c, width: tp.width + 16, height: tp.height + 9);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(7)),
          Paint()..color = AppColors.gold.withValues(alpha: 0.14));
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(7)),
          Paint()
            ..color = AppColors.gold.withValues(alpha: 0.50)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);
    }

    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant RangeZonePainter old) =>
      old.selectedId != selectedId;
}

// ═════════════════════════════════════════════════════════════════════════════
//  COURT LINE PAINTER
// ═════════════════════════════════════════════════════════════════════════════

class CourtLinePainter extends CustomPainter {
  final CourtGeo g;
  const CourtLinePainter(this.g);

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, g.w, g.h),
        Paint()..color = const Color(0xFF161618));

    final line = Paint()
      ..color = const Color(0xFF353540)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final faint = Paint()
      ..color = const Color(0xFF353540).withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Boundary lines
    canvas.drawLine(Offset(0, g.baseY), Offset(g.w, g.baseY), line); // baseline
    canvas.drawLine(
        const Offset(1, 0), Offset(1, g.baseY), line); // left sideline
    canvas.drawLine(
        Offset(g.w - 1, 0), Offset(g.w - 1, g.baseY), line); // right sideline
    canvas.drawLine(const Offset(0, 1), Offset(g.w, 1), line); // half-court

    // Three-point arc + corner straights
    canvas.drawArc(
      Rect.fromCircle(center: Offset(g.bx, g.by), radius: g.tpArcR),
      g.tpStartAngle,
      g.tpSweepAngle,
      false,
      line,
    );
    canvas.drawLine(
        Offset(g.tpL, g.tpIntersectY), Offset(g.tpL, g.baseY), line);
    canvas.drawLine(
        Offset(g.tpR, g.tpIntersectY), Offset(g.tpR, g.baseY), line);

    // Key box
    canvas.drawRect(Rect.fromLTRB(g.keyL, g.ftY, g.keyR, g.baseY), line);

    // Free-throw circle — solid top half, faint bottom half
    canvas.drawArc(Rect.fromCircle(center: Offset(g.bx, g.ftY), radius: g.ftR),
        math.pi, math.pi, false, line);
    canvas.drawArc(Rect.fromCircle(center: Offset(g.bx, g.ftY), radius: g.ftR),
        0, math.pi, false, faint);

    // Restricted area arc
    canvas.drawArc(Rect.fromCircle(center: Offset(g.bx, g.by), radius: g.raR),
        math.pi, math.pi, false, faint);

    // Rim (gold)
    canvas.drawCircle(
        Offset(g.bx, g.by),
        g.w * 0.040,
        Paint()
          ..color = AppColors.gold.withValues(alpha: 0.55)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke);

    // Backboard
    canvas.drawLine(
      Offset(g.bx - g.w * 0.060, g.by + g.w * 0.074),
      Offset(g.bx + g.w * 0.060, g.by + g.w * 0.074),
      Paint()
        ..color = AppColors.text2.withValues(alpha: 0.45)
        ..strokeWidth = 2.4,
    );
  }

  @override
  bool shouldRepaint(CourtLinePainter _) => false;
}

// ═════════════════════════════════════════════════════════════════════════════
//  SPOT WIDGET  (used by both SessionSetup and ManualEntry)
// ═════════════════════════════════════════════════════════════════════════════

class CourtSpotWidget extends StatefulWidget {
  final bool selected;
  final String label;
  const CourtSpotWidget(
      {required this.selected, required this.label, super.key});
  @override
  State<CourtSpotWidget> createState() => _CourtSpotWidgetState();
}

class _CourtSpotWidgetState extends State<CourtSpotWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 56,
        height: 56,
        child: Stack(alignment: Alignment.center, children: [
          if (widget.selected)
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: 38 * (0.76 + 0.24 * _pulse.value),
                height: 38 * (0.76 + 0.24 * _pulse.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold
                        .withValues(alpha: 0.50 * (1 - _pulse.value)),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.selected ? 14 : 9,
            height: widget.selected ? 14 : 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.selected
                  ? AppColors.gold
                  : AppColors.text3.withValues(alpha: 0.40),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.50),
                          blurRadius: 10,
                          spreadRadius: 1)
                    ]
                  : null,
            ),
          ),
        ]),
      );
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
                      color: active ? AppColors.bg : AppColors.text3)),
            ),
          ),
        ),
      );
}
