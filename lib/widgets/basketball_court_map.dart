import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../main.dart';
import '../utils/performance.dart';
// ─────────────────────────────────────────────────────────────────────────────
//  Models
// ─────────────────────────────────────────────────────────────────────────────

enum CourtMapMode {
  /// Interactive setup: grey spots, selected is gold, no stats inside.
  setup,

  /// Statistical overview: heatmap-colored spots based on %, shows % inside.
  stats,

  /// Range breakdown: filled zones (layup, close, mid, three).
  range,
}

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
  final int tier; // 0=layup, 1=close, 2=mid, 3=three
  const RangeZone(this.id, this.label, this.tier);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Geometry
// ─────────────────────────────────────────────────────────────────────────────

class CourtGeo {
  final double w, h;
  CourtGeo(this.w, this.h);

  double get baseY => h - 22.0; // Slightly more padding from bottom
  double get bx => w / 2;
  double get by => baseY - w * 0.105;
  double get keyL => bx - w * 0.160; // 16ft width (NBA)
  double get keyR => bx + w * 0.160;
  double get ftY => baseY - w * 0.380; // 19ft (NBA)
  double get ftR => w * 0.120;
  double get tpArcR => w * 0.475; // 23.75ft (NBA)
  double get tpL => bx - w * 0.440;
  double get tpR => bx + w * 0.440;

  double get tpIntersectY =>
      by - math.sqrt(tpArcR * tpArcR - math.pow(tpL - bx, 2));
  double get tpStartAngle => math.atan2(tpIntersectY - by, tpL - bx);
  double get tpSweepAngle =>
      math.atan2(tpIntersectY - by, tpR - bx) - tpStartAngle;
  double get raR => w * 0.083;

  List<MapSpotData> get defaultSpots {
    return [
      const MapSpotData(id: 'left_corner', label: 'Left Corner'),
      const MapSpotData(id: 'right_corner', label: 'Right Corner'),
      const MapSpotData(id: 'left_wing', label: 'Left Wing'),
      const MapSpotData(id: 'right_wing', label: 'Right Wing'),
      const MapSpotData(id: 'top_arc', label: 'Top of Arc'),
      const MapSpotData(id: 'left_elbow', label: 'Left Elbow'),
      const MapSpotData(id: 'right_elbow', label: 'Right Elbow'),
      const MapSpotData(id: 'left_block', label: 'Left Block'),
      const MapSpotData(id: 'right_block', label: 'Right Block'),
      const MapSpotData(id: 'free_throw', label: 'Free Throw'),
      const MapSpotData(id: 'high_arc', label: 'High Arc'),
      const MapSpotData(id: 'left_mid', label: 'Left Mid'),
      const MapSpotData(id: 'right_mid', label: 'Right Mid'),
    ];
  }

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
      case 'top_of_arc': // Map standard label to offset
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_activeTooltipId != null) {
          setState(() => _activeTooltipId = null);
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
                  // 1. Court Lines
                  Positioned.fill(
                    child: CustomPaint(
                        painter: _CourtLinePainter(geo, widget.themeColor)),
                  ),

                  // 2. Range Zones (if in range mode)
                  if (widget.mode == CourtMapMode.range)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RangeZonePainter(
                            geo, widget.selectedId, widget.zones,
                            themeColor: widget.themeColor),
                      ),
                    ),

                  // 3. Spots Interactive Layer
                  if (widget.mode == CourtMapMode.range)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          final id =
                              _RangeZonePainter.getZoneAt(geo, d.localPosition);
                          if (id != null && widget.onSpotTap != null) {
                            widget.onSpotTap!(id);
                          }
                        },
                        child: const SizedBox.expand(),
                      ),
                    )
                  else
                    ...widget.spots.map((s) {
                      final offset = geo.getSpotOffset(s.id);
                      return Positioned(
                        left: offset.dx - 21,
                        top: offset.dy - 21,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (widget.mode == CourtMapMode.stats) {
                              setState(() {
                                _activeTooltipId =
                                    _activeTooltipId == s.id ? null : s.id;
                              });
                            } else {
                              widget.onSpotTap?.call(s.id);
                            }
                          },
                          child: _CourtSpotMarker(
                            id: s.id,
                            label: s.label,
                            pct: s.pct,
                            attempts: s.attempts,
                            isSelected:
                                s.id == widget.selectedId || s.isSelected,
                            mode: widget.mode,
                            themeColor: widget.themeColor,
                          ),
                        ),
                      );
                    }),

                  // 4. Tooltips (top layer)
                  if (widget.mode == CourtMapMode.stats &&
                      _activeTooltipId != null)
                    ...widget.spots
                        .where((s) => s.id == _activeTooltipId)
                        .map((s) {
                      final offset = geo.getSpotOffset(s.id);
                      // Clamp tooltip horizontal position so it doesn't overflow
                      final left = (offset.dx - 60).clamp(8.0, geo.w - 128.0);
                      return Positioned(
                        left: left,
                        top: offset.dy - 64, // above the spot
                        child: _TooltipOverlay(spot: s),
                      );
                    }),

                  // 5. Instruction text (top right)
                  if (widget.mode == CourtMapMode.stats)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Text(
                        'Tap spots for detail',
                        style: AppText.ui(11,
                            color: AppColors.text3.withValues(alpha: 0.6),
                            weight: FontWeight.w600),
                      ),
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
//  Sub-Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TooltipOverlay extends StatelessWidget {
  final MapSpotData spot;
  const _TooltipOverlay({required this.spot});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120, // fixed width for consistent look
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            spot.label,
            style: AppText.ui(10,
                color: AppColors.text3,
                weight: FontWeight.w600,
                letterSpacing: 0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(spot.pct * 100).round()}%',
                style: AppText.display(18, color: AppColors.text1),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '($_made/${spot.attempts})',
                  style: AppText.ui(10, color: AppColors.text3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int get _made => (spot.pct * spot.attempts).round();
}

class _CourtSpotMarker extends StatefulWidget {
  final String id;
  final String label;
  final double pct;
  final int attempts;
  final bool isSelected;
  final CourtMapMode mode;
  final Color themeColor;

  const _CourtSpotMarker({
    required this.id,
    required this.label,
    required this.pct,
    required this.attempts,
    required this.isSelected,
    required this.mode,
    required this.themeColor,
  });

  @override
  State<_CourtSpotMarker> createState() => _CourtSpotMarkerState();
}

class _CourtSpotMarkerState extends State<_CourtSpotMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    if (widget.mode == CourtMapMode.setup) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_CourtSpotMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode == CourtMapMode.setup) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == CourtMapMode.setup) {
      return _buildSetupMarker();
    } else {
      return _buildStatsMarker();
    }
  }

  Widget _buildSetupMarker() {
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

  Widget _buildStatsMarker() {
    final Color dotColor = PerformanceGuide.colorFor(widget.pct);

    const radius = 4.5;

    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse Ring Effect
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
          // Fill
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              boxShadow: [
                BoxShadow(
                    color: dotColor.withValues(alpha: 0.40),
                    blurRadius: 8,
                    spreadRadius: 1)
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
        children: items.map((item) {
          return Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item.$2,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(item.$1,
                style: AppText.ui(12,
                    color: AppColors.text2, weight: FontWeight.w600)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Painters
// ─────────────────────────────────────────────────────────────────────────────

class _CourtLinePainter extends CustomPainter {
  final CourtGeo g;
  final Color themeColor;
  const _CourtLinePainter(this.g, this.themeColor);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, 0, g.w, g.baseY + 2)); // Slightly past baseline

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
      line,
    );
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
    final inLayup = dx * dx + dy * dy <= g.raR * g.raR;
    return inLayup ? 'layup' : 'close';
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
      final p = buildZonePath(g, z.tier);
      canvas.drawPath(
          p,
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
