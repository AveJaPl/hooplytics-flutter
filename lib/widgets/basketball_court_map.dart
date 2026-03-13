import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../main.dart';
import '../utils/performance.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Models
// ─────────────────────────────────────────────────────────────────────────────

enum CourtMapMode { setup, stats, range }

class MapSpotData {
  final String id;
  final String label;
  final double pct;
  final int attempts;
  final bool isSelected;

  const MapSpotData({
    required this.id,
    required this.label,
    this.pct = 0.0,
    this.attempts = 0,
    this.isSelected = false,
  });
}

class RangeZone {
  final String id;
  final String label;
  final int tier;
  const RangeZone(this.id, this.label, this.tier);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Geometry
// ─────────────────────────────────────────────────────────────────────────────

class CourtGeo {
  final double w, h;
  CourtGeo(this.w, this.h);

  double get baseY => h - 22.0;
  double get bx => w / 2;
  double get by => baseY - w * 0.105;
  double get keyL => bx - w * 0.160;
  double get keyR => bx + w * 0.160;
  double get ftY => baseY - w * 0.380;
  double get ftR => w * 0.120;
  double get tpArcR => w * 0.475;
  double get tpL => bx - w * 0.440;
  double get tpR => bx + w * 0.440;

  double get tpIntersectY =>
      by - math.sqrt(tpArcR * tpArcR - math.pow(tpL - bx, 2));
  double get tpStartAngle => math.atan2(tpIntersectY - by, tpL - bx);
  double get tpSweepAngle =>
      math.atan2(tpIntersectY - by, tpR - bx) - tpStartAngle;
  double get raR => w * 0.083;

  Offset getSpotOffset(String id) {
    final spotR = tpArcR + w * 0.024;
    final cornerXPad = w * 0.028;
    arcX(double dx) => bx + dx * w;
    arcY(double absDx) {
      final px = absDx * w;
      if (px >= spotR) return by;
      return by - math.sqrt(spotR * spotR - px * px);
    }

    switch (id) {
      case 'left_corner':
        return Offset(tpL - cornerXPad, baseY - w * 0.045);
      case 'right_corner':
        return Offset(tpR + cornerXPad, baseY - w * 0.045);
      case 'left_wing':
        return Offset(arcX(-0.385), arcY(0.385));
      case 'right_wing':
        return Offset(arcX(0.385), arcY(0.385));
      case 'top_arc':
      case 'top_of_arc':
        return Offset(bx, arcY(0));
      case 'left_elbow':
        return Offset(keyL, ftY);
      case 'right_elbow':
        return Offset(keyR, ftY);
      case 'left_block':
        return Offset(keyL + w * 0.024, by + w * 0.072);
      case 'right_block':
        return Offset(keyR - w * 0.024, by + w * 0.072);
      case 'free_throw':
        return Offset(bx, ftY);
      case 'high_arc':
        return Offset(bx, ftY - w * 0.150);
      case 'left_mid':
        return Offset(keyL - w * 0.135, by - w * 0.115);
      case 'right_mid':
        return Offset(keyR + w * 0.135, by - w * 0.115);
      default:
        return Offset(bx, by);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main Widget
// ─────────────────────────────────────────────────────────────────────────────

class BasketballCourtMap extends StatefulWidget {
  final CourtMapMode mode;
  final List<MapSpotData> spots;
  final List<RangeZone> zones;
  final String? selectedId;
  final Function(String id)? onSpotTap;
  final bool showLegend;
  final bool showLabels;
  final double aspectRatio;
  final Color themeColor;

  const BasketballCourtMap({
    super.key,
    this.mode = CourtMapMode.stats,
    this.spots = const [],
    this.zones = const [
      RangeZone('layup', 'Layup', 0),
      RangeZone('close', 'Close Shot', 1),
      RangeZone('mid', 'Mid Range', 2),
      RangeZone('three', 'Three Point', 3),
    ],
    this.selectedId,
    this.onSpotTap,
    this.showLegend = false,
    this.showLabels = true,
    this.aspectRatio = 1.05,
    this.themeColor = AppColors.gold,
  });

  @override
  State<BasketballCourtMap> createState() => _BasketballCourtMapState();
}

class _BasketballCourtMapState extends State<BasketballCourtMap> {
  String? _activeTooltipId;
  String? _randomPulseId;
  final List<String> _recentPulseIds = [];
  Timer? _pulseTimer;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    if (widget.mode == CourtMapMode.stats) _schedulePulse();
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  // ── Pulse scheduler ────────────────────────────────────────────────────────
  // Pattern: wait → light up one dot → wait for it to fade → repeat.
  // When a tooltip is open all random pulsing stops.

  void _schedulePulse() {
    _pulseTimer?.cancel();
    // Tiny gap between dots: 100–300ms
    final delay = 100 + _random.nextInt(200);
    _pulseTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      if (_activeTooltipId != null) {
        _schedulePulse();
        return;
      }
      if (widget.spots.isEmpty) {
        _schedulePulse();
        return;
      }

      final all = widget.spots.map((s) => s.id).toList();

      // History size: exclude up to half the spots (min 1, max 4)
      // so with 4 spots we exclude 2, with 10 spots we exclude 4
      final historySize = (all.length ~/ 2).clamp(1, 4);

      // Build candidate list — exclude recently shown
      var candidates =
          all.where((id) => !_recentPulseIds.contains(id)).toList();
      // Fallback: if all excluded (very few spots), just exclude the last one
      if (candidates.isEmpty) {
        candidates = all.where((id) => id != _randomPulseId).toList();
        if (candidates.isEmpty) candidates = all;
      }

      final next = candidates[_random.nextInt(candidates.length)];

      // Update history
      _recentPulseIds.add(next);
      while (_recentPulseIds.length > historySize) {
        _recentPulseIds.removeAt(0);
      }

      setState(() => _randomPulseId = next);

      // Pulse: 1000ms in + 1000ms out = 2000ms. Clear after 2100ms.
      _pulseTimer = Timer(const Duration(milliseconds: 2100), () {
        if (mounted) setState(() => _randomPulseId = null);
        _schedulePulse();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_activeTooltipId != null) {
          setState(() => _activeTooltipId = null);
          // Re-start pulsing now that tooltip is closed
          _schedulePulse();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: LayoutBuilder(builder: (context, constraints) {
              final geo = CourtGeo(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Court lines
                  Positioned.fill(
                    child: CustomPaint(
                        painter: _CourtLinePainter(geo, widget.themeColor)),
                  ),

                  // 2. Range zones
                  if (widget.mode == CourtMapMode.range)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RangeZonePainter(
                            geo, widget.selectedId, widget.zones,
                            themeColor: widget.themeColor),
                      ),
                    ),

                  // 3. Spot / zone interaction layer
                  if (widget.mode == CourtMapMode.range)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          final id =
                              _RangeZonePainter.getZoneAt(geo, d.localPosition);
                          if (id != null) widget.onSpotTap?.call(id);
                        },
                        child: const SizedBox.expand(),
                      ),
                    )
                  else
                    ...widget.spots.map((s) {
                      final offset = geo.getSpotOffset(s.id);
                      final isActive = s.id == _activeTooltipId;
                      // In stats mode: pulse only if no tooltip is open
                      final isPulsing = widget.mode == CourtMapMode.stats &&
                          _activeTooltipId == null &&
                          s.id == _randomPulseId;

                      return Positioned(
                        left: offset.dx - 21,
                        top: offset.dy - 21,
                        child: GestureDetector(
                          key: ValueKey('spot_${s.id}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (widget.mode == CourtMapMode.stats) {
                              setState(() {
                                _activeTooltipId = isActive ? null : s.id;
                                // Stop random pulse immediately
                                _randomPulseId = null;
                              });
                              if (_activeTooltipId == null) {
                                // Tooltip closed → restart random pulsing
                                _schedulePulse();
                              } else {
                                // Tooltip open → stop the scheduler
                                _pulseTimer?.cancel();
                              }
                            } else {
                              widget.onSpotTap?.call(s.id);
                            }
                          },
                          child: _CourtSpotMarker(
                            id: s.id,
                            label: s.label,
                            pct: s.pct,
                            attempts: s.attempts,
                            isSelected: s.id == widget.selectedId ||
                                s.isSelected ||
                                isActive,
                            isPulsing: isPulsing,
                            mode: widget.mode,
                            themeColor: widget.themeColor,
                          ),
                        ),
                      );
                    }),

                  // 4. Tooltip (top layer)
                  if (widget.mode == CourtMapMode.stats &&
                      _activeTooltipId != null)
                    ...widget.spots
                        .where((s) => s.id == _activeTooltipId)
                        .map((s) {
                      final offset = geo.getSpotOffset(s.id);
                      final left = (offset.dx - 60).clamp(8.0, geo.w - 128.0);
                      return Positioned(
                        left: left,
                        top: offset.dy - 64,
                        child: _TooltipOverlay(spot: s),
                      );
                    }),

                  // 5. Hint text
                  if (widget.mode == CourtMapMode.stats)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Text('Tap spots for detail',
                          style: AppText.ui(13,
                              color: AppColors.text2, weight: FontWeight.w600)),
                    ),
                ],
              );
            }),
          ),
          if (widget.showLegend && widget.mode == CourtMapMode.stats) ...[
            const SizedBox(height: 8),
            _MapLegend(),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Spot Marker
// ─────────────────────────────────────────────────────────────────────────────

class _CourtSpotMarker extends StatefulWidget {
  final String id;
  final String label;
  final double pct;
  final int attempts;
  final bool isSelected;
  final bool isPulsing;
  final CourtMapMode mode;
  final Color themeColor;

  const _CourtSpotMarker({
    required this.id,
    required this.label,
    required this.pct,
    required this.attempts,
    required this.isSelected,
    this.isPulsing = false,
    required this.mode,
    required this.themeColor,
  });

  @override
  State<_CourtSpotMarker> createState() => _CourtSpotMarkerState();
}

class _CourtSpotMarkerState extends State<_CourtSpotMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _applyState();
  }

  @override
  void didUpdateWidget(_CourtSpotMarker old) {
    super.didUpdateWidget(old);
    if (old.isSelected != widget.isSelected ||
        old.isPulsing != widget.isPulsing) {
      _applyState();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ── Clean state machine ────────────────────────────────────────────────────

  void _applyState() {
    if (widget.mode == CourtMapMode.setup) {
      // Setup mode: selected dot breathes, others are static
      if (widget.isSelected) {
        _pulse.duration = const Duration(milliseconds: 900);
        _pulse.repeat(reverse: true);
      } else {
        _pulse.stop();
        _pulse.reset();
      }
      return;
    }

    // Stats mode
    if (widget.isSelected) {
      // Continuous slow breathing — selected dot
      _pulse.stop();
      _pulse.duration = const Duration(milliseconds: 1300);
      _pulse.repeat(reverse: true);
    } else if (widget.isPulsing) {
      _pulse.stop();
      _pulse.duration = const Duration(milliseconds: 1000);
      _pulse.repeat(reverse: true);
    } else {
      // Not selected, not pulsing → smoothly fade to zero and stop
      _pulse.stop();
      if (_pulse.value > 0) {
        _pulse.duration = const Duration(milliseconds: 300);
        _pulse.reverse();
      } else {
        _pulse.reset();
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) =>
      widget.mode == CourtMapMode.setup ? _setupMarker() : _statsMarker();

  // Setup: grey dot, selected = gold pulsing ring
  Widget _setupMarker() {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(alignment: Alignment.center, children: [
        if (widget.isSelected)
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 38 * (0.76 + 0.24 * _pulse.value),
              height: 38 * (0.76 + 0.24 * _pulse.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.themeColor
                      .withValues(alpha: 0.50 * (1 - _pulse.value)),
                  width: 1.4,
                ),
              ),
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.isSelected ? 14 : 9,
          height: widget.isSelected ? 14 : 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isSelected
                ? widget.themeColor
                : AppColors.text3.withValues(alpha: 0.40),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                        color: widget.themeColor.withValues(alpha: 0.50),
                        blurRadius: 10,
                        spreadRadius: 1)
                  ]
                : null,
          ),
        ),
      ]),
    );
  }

  // Stats: identical animation to setup — fixed dot, ring expands & fades
  Widget _statsMarker() {
    final dotColor = PerformanceGuide.colorFor(widget.pct);
    final isActive = widget.isSelected || widget.isPulsing;

    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(alignment: Alignment.center, children: [
        // Ring — exact same math as setup marker
        if (isActive)
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 38 * (0.76 + 0.24 * _pulse.value),
              height: 38 * (0.76 + 0.24 * _pulse.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: dotColor.withValues(alpha: 0.50 * (1 - _pulse.value)),
                  width: 1.4,
                ),
              ),
            ),
          ),
        // Dot — fixed size, just like setup marker
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.isSelected ? 14 : 11,
          height: widget.isSelected ? 14 : 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                        color: dotColor.withValues(alpha: 0.50),
                        blurRadius: 10,
                        spreadRadius: 1)
                  ]
                : null,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tooltip overlay
// ─────────────────────────────────────────────────────────────────────────────

class _TooltipOverlay extends StatelessWidget {
  final MapSpotData spot;
  const _TooltipOverlay({required this.spot});

  int get _made => (spot.pct * spot.attempts).round();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(spot.label,
            style: AppText.ui(10,
                color: AppColors.text3,
                weight: FontWeight.w600,
                letterSpacing: 0.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${(spot.pct * 100).round()}%',
                style: AppText.display(18, color: AppColors.text1)),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('($_made/${spot.attempts})',
                  style: AppText.ui(10, color: AppColors.text3)),
            ),
          ],
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Legend
// ─────────────────────────────────────────────────────────────────────────────

class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      ('≥70%', AppColors.green),
      ('50–69%', AppColors.gold),
      ('<50%', AppColors.red),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items
            .map((item) => Row(children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: item.$2, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(item.$1,
                      style: AppText.ui(12,
                          color: AppColors.text2, weight: FontWeight.w600)),
                ]))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Painters (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _CourtLinePainter extends CustomPainter {
  final CourtGeo g;
  final Color themeColor;
  const _CourtLinePainter(this.g, this.themeColor);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, g.w, g.baseY + 2));
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

    canvas.drawLine(Offset(0, g.baseY), Offset(g.w, g.baseY), line);
    canvas.drawLine(const Offset(1, 0), Offset(1, g.baseY), line);
    canvas.drawLine(Offset(g.w - 1, 0), Offset(g.w - 1, g.baseY), line);
    canvas.drawLine(const Offset(0, 1), Offset(g.w, 1), line);

    canvas.drawArc(
        Rect.fromCircle(center: Offset(g.bx, g.by), radius: g.tpArcR),
        g.tpStartAngle,
        g.tpSweepAngle,
        false,
        line);
    canvas.drawLine(
        Offset(g.tpL, g.tpIntersectY), Offset(g.tpL, g.baseY), line);
    canvas.drawLine(
        Offset(g.tpR, g.tpIntersectY), Offset(g.tpR, g.baseY), line);
    canvas.drawRect(Rect.fromLTRB(g.keyL, g.ftY, g.keyR, g.baseY), line);
    canvas.drawArc(Rect.fromCircle(center: Offset(g.bx, g.ftY), radius: g.ftR),
        math.pi, math.pi, false, line);
    canvas.drawArc(Rect.fromCircle(center: Offset(g.bx, g.ftY), radius: g.ftR),
        0, math.pi, false, faint);
    canvas.drawArc(Rect.fromCircle(center: Offset(g.bx, g.by), radius: g.raR),
        math.pi, math.pi, false, faint);
    canvas.drawCircle(
        Offset(g.bx, g.by),
        g.w * 0.040,
        Paint()
          ..color = themeColor.withValues(alpha: 0.55)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke);
    canvas.drawLine(
      Offset(g.bx - g.w * 0.060, g.by + g.w * 0.074),
      Offset(g.bx + g.w * 0.060, g.by + g.w * 0.074),
      Paint()
        ..color = AppColors.text2.withValues(alpha: 0.45)
        ..strokeWidth = 2.4,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_) => false;
}

class _RangeZonePainter extends CustomPainter {
  final CourtGeo g;
  final String? selectedId;
  final List<RangeZone> zones;
  final Color themeColor;

  const _RangeZonePainter(this.g, this.selectedId, this.zones,
      {required this.themeColor});

  static String? getZoneAt(CourtGeo g, Offset p) {
    if (!_tp(g).contains(p)) return 'three';
    final inKey =
        p.dx >= g.keyL && p.dx <= g.keyR && p.dy >= g.ftY && p.dy <= g.baseY;
    if (!inKey) return 'mid';
    final dx = p.dx - g.bx, dy = p.dy - g.by;
    return dx * dx + dy * dy <= g.raR * g.raR ? 'layup' : 'close';
  }

  static Path _tp(CourtGeo g) {
    final p = Path();
    p.moveTo(g.tpL, g.baseY);
    p.lineTo(g.tpL, g.tpIntersectY);
    p.arcTo(Rect.fromCircle(center: Offset(g.bx, g.by), radius: g.tpArcR),
        g.tpStartAngle, g.tpSweepAngle, false);
    p.lineTo(g.tpR, g.baseY);
    p.close();
    return p;
  }

  static Path buildZonePath(CourtGeo g, int tier) {
    switch (tier) {
      case 0:
        return Path()
          ..addOval(Rect.fromCircle(center: Offset(g.bx, g.by), radius: g.raR));
      case 1:
        return Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Rect.fromLTRB(g.keyL, g.ftY, g.keyR, g.baseY))
          ..addOval(Rect.fromCircle(center: Offset(g.bx, g.by), radius: g.raR));
      case 2:
        return Path()
          ..fillType = PathFillType.evenOdd
          ..addPath(_tp(g), Offset.zero)
          ..addRect(Rect.fromLTRB(g.keyL, g.ftY, g.keyR, g.baseY));
      case 3:
      default:
        return Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Rect.fromLTRB(0, 0, g.w, g.baseY))
          ..addPath(_tp(g), Offset.zero);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, g.w, g.baseY));
    for (final z in zones) {
      if (z.id == selectedId) continue;
      canvas.drawPath(
          buildZonePath(g, z.tier),
          Paint()
            ..color = AppColors.text3.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);
      _label(canvas, z.label, _center(z.tier), false);
    }
    if (selectedId != null) {
      final z = zones.firstWhere((z) => z.id == selectedId,
          orElse: () => zones.first);
      canvas.drawPath(
          buildZonePath(g, z.tier),
          Paint()
            ..color = themeColor.withValues(alpha: 0.16)
            ..style = PaintingStyle.fill);
      _label(canvas, z.label, _center(z.tier), true);
    }
    canvas.restore();
  }

  Offset _center(int tier) {
    switch (tier) {
      case 0:
        return Offset(g.bx, g.by);
      case 1:
        return Offset(g.bx, g.ftY + (g.baseY - g.ftY) * 0.32);
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
                    ? themeColor
                    : AppColors.text2.withValues(alpha: 0.6),
                fontSize: selected ? 13.0 : 11.5,
                fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RangeZonePainter old) =>
      old.selectedId != selectedId;
}
