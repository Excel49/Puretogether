import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DustGaugeWidget extends StatelessWidget {
  final double dustLevel;
  final String airStatus;

  const DustGaugeWidget({super.key, required this.dustLevel, required this.airStatus});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(airStatus);
    final pct = (dustLevel / 200).clamp(0.0, 1.0);

    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 124,
          child: CustomPaint(
            painter: _GaugePainter(percent: pct, color: color),
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dustLevel.toStringAsFixed(1),
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color),
                  ),
                  const Text('µg/m³',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              _ThresholdChip(label: 'WHO 15', color: AppTheme.safe),
              _ThresholdChip(label: 'Batas 75', color: AppTheme.warning),
              Text('200', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThresholdChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ThresholdChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  final Color color;

  const _GaugePainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.9;
    final radius = size.width * 0.44;
    final sw = size.width * 0.075;

    const startAngle = math.pi;
    const sweepFull = math.pi;

    final trackPaint = Paint()
      ..color = AppTheme.surfaceBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle, sweepFull, false, trackPaint,
    );

    if (percent > 0) {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round;

      // Gradient via shader
      fillPaint.shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepFull * percent,
        colors: const [AppTheme.safe, AppTheme.warning, AppTheme.danger],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle, sweepFull * percent, false, fillPaint,
      );
    }

    // Needle
    final needleAngle = math.pi + percent * math.pi;
    final needleEnd = Offset(
      cx + radius * 0.72 * math.cos(needleAngle),
      cy + radius * 0.72 * math.sin(needleAngle),
    );
    canvas.drawLine(
      Offset(cx, cy), needleEnd,
      Paint()..color = Colors.white70..strokeWidth = 2..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx, cy), sw * 0.5,
      Paint()..color = AppTheme.surfaceElevated);
    canvas.drawCircle(Offset(cx, cy), sw * 0.35,
      Paint()..color = AppTheme.textSecondary);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.percent != percent || old.color != color;
}
