import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MapCanvas extends StatefulWidget {
  final String? mapData;
  final String? currentLine;
  final String? checkpoint;

  const MapCanvas({
    super.key,
    this.mapData,
    this.currentLine,
    this.checkpoint,
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
  final String? mapData;
  final double pulseValue;

  _WireframeTrackPainter({
    this.mapData,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── 1. Soft Floor Background with Subtle Grid Lines ────────────────────────
    final bgPaint = Paint()..color = const Color(0xFFF8FAFC);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(16)),
      bgPaint,
    );

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

    // ── 2. Cek apakah ada mapData tersimpan ──────────────────────────────────
    final hasMap = mapData != null && mapData!.trim().isNotEmpty;

    if (!hasMap) {
      // DEFAULT KOSONG: Hanya tampilkan tanda bulat robot di tengah kanvas
      final center = Offset(w / 2, h / 2);

      // Outer Pulsing Halo
      final haloPaint = Paint()
        ..color = AppTheme.primary.withValues(alpha: (1 - pulseValue) * 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 20 + (pulseValue * 12), haloPaint);

      // Robot Avatar Circle
      _drawRobotAvatar(canvas, center);

      // Subtitle di bawah robot
      const textStyle = TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      );
      final textPainter = TextPainter(
        text: const TextSpan(text: 'Posisi Awal Robot • Siap untuk Pemetaan', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset((w - textPainter.width) / 2, h / 2 + 32),
      );
      return;
    }

    // ── 3. JIKA ADA PETA: Gambar rute secara dinamis dari mapData ───────────
    _drawDynamicRoute(canvas, size);
  }

  void _drawDynamicRoute(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final tokens = mapData!.split(',').where((s) => s.isNotEmpty).toList();
    if (tokens.isEmpty) return;

    // Awal koordinat rute
    Offset current = Offset(w * 0.22, h * 0.78);
    final List<Offset> points = [current];

    // Orientasi arah: 0 = Atas, 1 = Kanan, 2 = Bawah, 3 = Kiri
    int dir = 0; // Mulai menghadap ke atas
    const double stepDistance = 42.0;

    void addStepForward() {
      switch (dir) {
        case 0:
          current = Offset(current.dx, (current.dy - stepDistance).clamp(24.0, h - 24.0));
          break;
        case 1:
          current = Offset((current.dx + stepDistance).clamp(24.0, w - 24.0), current.dy);
          break;
        case 2:
          current = Offset(current.dx, (current.dy + stepDistance).clamp(24.0, h - 24.0));
          break;
        case 3:
          current = Offset((current.dx - stepDistance).clamp(24.0, w - 24.0), current.dy);
          break;
      }
      points.add(current);
    }

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.startsWith('L')) {
        // Jalan Lurus
        addStepForward();
      } else if (token == 'K') {
        // Belok Lurus Kanan
        dir = (dir + 1) % 4;
        final nextIsStraight = (i + 1 < tokens.length) && tokens[i + 1].startsWith('L');
        if (!nextIsStraight) {
          addStepForward();
        }
      } else if (token == 'Ki') {
        // Belok Lurus Kiri
        dir = (dir + 3) % 4;
        final nextIsStraight = (i + 1 < tokens.length) && tokens[i + 1].startsWith('L');
        if (!nextIsStraight) {
          addStepForward();
        }
      }
    }

    // Gambar Path Garis Rute
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      // Glow bawah
      final glowPaint = Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, glowPaint);

      // Garis utama rute
      final linePaint = Paint()
        ..color = AppTheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, linePaint);
    }

    // Gambar Titik Node Sudut
    for (int i = 0; i < points.length - 1; i++) {
      final p = points[i];
      if (i == 0) {
        // Start Flag (Hijau)
        canvas.drawCircle(p, 6.0, Paint()..color = const Color(0xFF16A34A));
        canvas.drawCircle(p, 3.5, Paint()..color = Colors.white);
      } else {
        // Sudut Belok (Putih + Border Abu)
        canvas.drawCircle(p, 4.0, Paint()..color = Colors.white);
        canvas.drawCircle(
          p,
          4.0,
          Paint()
            ..color = const Color(0xFF94A3B8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    // Robot Avatar di Titik Terakhir / Posisi Aktif
    final robotPos = points.last;
    final haloPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: (1 - pulseValue) * 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(robotPos, 18 + (pulseValue * 10), haloPaint);
    _drawRobotAvatar(canvas, robotPos);
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

    // Cyan visor eyes
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

  @override
  bool shouldRepaint(covariant _WireframeTrackPainter oldDelegate) {
    return oldDelegate.mapData != mapData || oldDelegate.pulseValue != pulseValue;
  }
}
