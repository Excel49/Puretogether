import 'package:flutter/material.dart';
import '../models/robot_data.dart';
import '../theme/app_theme.dart';
import 'dust_gauge.dart';

class AirQualityCard extends StatelessWidget {
  final RobotData data;
  const AirQualityCard({super.key, required this.data});

  String get _statusLabel {
    switch (data.airStatus) {
      case 'GOOD':    return 'BAIK';
      case 'WARNING': return 'WASPADA';
      case 'POOR':    return 'BERBAHAYA';
      default:        return '—';
    }
  }

  IconData get _statusIcon {
    switch (data.airStatus) {
      case 'GOOD':    return Icons.eco_rounded;
      case 'WARNING': return Icons.warning_amber_rounded;
      case 'POOR':    return Icons.dangerous_rounded;
      default:        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(data.airStatus);
    final glow  = AppTheme.statusGlow(data.airStatus);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: glow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('STATUS UDARA',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(_statusLabel,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                        color: color, letterSpacing: -0.5)),
                  ],
                ),
              ),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon, color: color, size: 32),
              ),
            ],
          ),
          const Divider(color: AppTheme.surfaceBorder, height: 24),
          // Gauge
          DustGaugeWidget(
            dustLevel: data.dustLevel,
            airStatus: data.airStatus,
          ),
        ],
      ),
    );
  }
}
