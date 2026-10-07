import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MapCanvas extends StatefulWidget {
  final String? currentLine;
  final String? checkpoint;
  final String? mapData;

  const MapCanvas({
    super.key,
    this.currentLine,
    this.checkpoint,
    this.mapData,
  });

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return SizedBox(
          height: 270,
          child: CustomPaint(
            painter: _WireframeTrackPainter(
              currentLine: widget.currentLine ?? 'B',
              checkpoint: widget.checkpoint ?? 'B-3',
              mapData: widget.mapData,
              pulseValue: _animCtrl.value,
            ),
            size: const Size(double.infinity, 270),
          ),
        );
      },
    );
  }
}

class _WireframeTrackPainter extends CustomPainter {
  final String currentLine;
  final String checkpoint;
  final String? mapData;
  final double pulseValue;

  _WireframeTrackPainter({
    required this.currentLine,
    required this.checkpoint,
    this.mapData,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── 1. Soft Floor Background with Grid Lines ─────────────────────────────
    final bgPaint = Paint()..color = const Color(0xFFF8FAFC);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(16)),
      bgPaint,
    );

    // Subtle grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.6)
      ..strokeWidth = 1.0;
    const double step = 24.0;
    for (double x = step; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = step; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // ── 2. Decorative Park / Foliage Patches ──────────────────────────────────
    _drawFoliagePatch(canvas, Offset(w * 0.12, h * 0.82), 26);
    _drawFoliagePatch(canvas, Offset(w * 0.88, h * 0.22), 22);
    _drawFoliagePatch(canvas, Offset(w * 0.88, h * 0.78), 24);

    // ── 3. Route Line Coordinates ───────────────────────────────────────────
    // Line A (Orange): Left Loop
    final pathA = Path()
      ..moveTo(w * 0.26, h * 0.18)
      ..lineTo(w * 0.42, h * 0.18)
      ..lineTo(w * 0.42, h * 0.68)
      ..lineTo(w * 0.26, h * 0.68)
      ..close();

    // Line B (Blue): Center corridor connecting to right loop
    final pathB = Path()
      ..moveTo(w * 0.52, h * 0.18)
      ..lineTo(w * 0.68, h * 0.40)
      ..lineTo(w * 0.68, h * 0.68)
      ..lineTo(w * 0.84, h * 0.68);

    // Line C (Green): Bottom corridor
    final pathC = Path()
      ..moveTo(w * 0.42, h * 0.68)
      ..lineTo(w * 0.60, h * 0.68)
      ..lineTo(w * 0.60, h * 0.86)
      ..lineTo(w * 0.78, h * 0.86);

    // ── 4. Draw Lines ────────────────────────────────────────────────────────
    // Line A (Orange)
    _drawRoute(canvas, pathA, AppTheme.lineA, currentLine == 'A', isDashed: false);

    // Line B (Blue) - Active
    _drawRoute(canvas, pathB, AppTheme.lineB, currentLine == 'B', isDashed: false);

    // Line C (Green)
    _drawRoute(canvas, pathC, AppTheme.lineC, currentLine == 'C', isDashed: true);

    // ── 5. Checkpoints / Nodes ───────────────────────────────────────────────
    final nodes = <Offset>[
      Offset(w * 0.26, h * 0.18),
      Offset(w * 0.42, h * 0.18),
      Offset(w * 0.42, h * 0.68),
      Offset(w * 0.26, h * 0.68),
      Offset(w * 0.52, h * 0.18),
      Offset(w * 0.68, h * 0.40),
      Offset(w * 0.68, h * 0.68),
      Offset(w * 0.84, h * 0.68),
      Offset(w * 0.60, h * 0.86),
      Offset(w * 0.78, h * 0.86),
    ];

    for (final node in nodes) {
      canvas.drawCircle(node, 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        node,
        4.5,
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // ── 6. Route Label Chips ─────────────────────────────────────────────────
    // Line A Badge
    _drawChip(canvas, Offset(w * 0.16, h * 0.38), 'Line A', const Color(0xFFF59E0B));
    // Line B Badge
    _drawChip(canvas, Offset(w * 0.78, h * 0.36), 'Line B', const Color(0xFF1B68D2));
    // Line C Badge
    _drawChip(canvas, Offset(w * 0.52, h * 0.86), 'Line C', const Color(0xFF10B981));

    // ── 7. Robot Location on Active Line (B) ──────────────────────────────────
    final robotPos = Offset(w * 0.68, h * 0.44);

    // Pulsing halo
    final haloPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: (1 - pulseValue) * 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(robotPos, 18 + (pulseValue * 10), haloPaint);

    // Robot Top-Down Mini Icon Avatar
    _drawRobotAvatar(canvas, robotPos);
  }

  void _drawRoute(Canvas canvas, Path path, Color color, bool isActive, {required bool isDashed}) {
    if (isActive) {
      // Glow under active route
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, glowPaint);
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isActive ? 4.5 : 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  void _drawChip(Canvas canvas, Offset center, String text, Color color) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w800,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final paddingH = 7.0;
    final paddingV = 3.5;
    final rect = Rect.fromCenter(
      center: center,
      width: textPainter.width + (paddingH * 2),
      height: textPainter.height + (paddingV * 2),
    );

    // Chip shadow & body
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    textPainter.paint(
      canvas,
      Offset(rect.left + paddingH, rect.top + paddingV),
    );
  }

  void _drawRobotAvatar(Canvas canvas, Offset pos) {
    // Outer white border
    canvas.drawCircle(
      pos,
      13,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      pos,
      13,
      Paint()
        ..color = AppTheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Inner robot base
    canvas.drawCircle(
      pos,
      9,
      Paint()
        ..color = const Color(0xFF0F1E36)
        ..style = PaintingStyle.fill,
    );

    // Cyan eyes inside visor
    canvas.drawCircle(
      Offset(pos.dx - 3.5, pos.dy),
      2.5,
      Paint()..color = const Color(0xFF38BDF8),
    );
    canvas.drawCircle(
      Offset(pos.dx + 3.5, pos.dy),
      2.5,
      Paint()..color = const Color(0xFF38BDF8),
    );
  }

  void _drawFoliagePatch(Canvas canvas, Offset center, double radius) {
    final patchPaint = Paint()
      ..color = const Color(0xFF86EFAC).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, patchPaint);

    final innerTreePaint = Paint()
      ..color = const Color(0xFF22C55E).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.55, innerTreePaint);
  }

  @override
  bool shouldRepaint(covariant _WireframeTrackPainter oldDelegate) {
    return oldDelegate.currentLine != currentLine ||
        oldDelegate.checkpoint != checkpoint ||
        oldDelegate.pulseValue != pulseValue;
  }
}
