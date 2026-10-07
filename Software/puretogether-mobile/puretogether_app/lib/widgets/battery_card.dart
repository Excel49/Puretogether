import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BatteryCard extends StatelessWidget {
  final int percent;
  final double voltage;

  const BatteryCard({super.key, required this.percent, required this.voltage});

  Color get _color {
    if (percent > 50) return AppTheme.safe;
    if (percent > 20) return AppTheme.warning;
    return AppTheme.danger;
  }

  IconData get _icon {
    if (percent > 75) return Icons.battery_full_rounded;
    if (percent > 50) return Icons.battery_5_bar_rounded;
    if (percent > 25) return Icons.battery_3_bar_rounded;
    if (percent > 10) return Icons.battery_1_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  String get _message {
    if (percent > 50) return 'Daya cukup untuk patroli';
    if (percent > 20) return 'Segera lakukan pengisian daya';
    return '⚠ Baterai kritis! Cas sekarang';
  }

  String get _estimate {
    if (percent > 50) return 'Est. 3+ jam';
    if (percent > 20) return 'Est. <1 jam';
    return 'Est. <15 mnt';
  }

  @override
  Widget build(BuildContext context) {
    final pct = percent.clamp(0, 100) / 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Battery visual
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon, color: _color, size: 26),
                  const SizedBox(width: 8),
                  Text('$percent%',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _color)),
                  const SizedBox(width: 6),
                  Text('${voltage.toStringAsFixed(1)}V',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(height: 10),
              // Bar
              Container(
                width: 110,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: FractionallySizedBox(
                  widthFactor: pct,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: [_color.withOpacity(0.7), _color],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_message,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                const SizedBox(height: 4),
                Text(_estimate,
                  style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
