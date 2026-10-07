import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool large;

  const StatusBadge({super.key, required this.status, this.large = false});

  static const _configs = {
    'GOOD':    ('✓ BAIK',       Color(0xFF00C853)),
    'WARNING': ('⚠ WASPADA',   Color(0xFFFFB800)),
    'POOR':    ('✕ BERBAHAYA', Color(0xFFFF4444)),
    'AUTO':    ('● AUTO',      Color(0xFF00E5FF)),
    'MANUAL':  ('◆ MANUAL',   Color(0xFFFFB800)),
    'ALERT':   ('! ALERT',     Color(0xFFFF4444)),
    'ONLINE':  ('● ONLINE',    Color(0xFF00C853)),
    'OFFLINE': ('○ OFFLINE',   Color(0xFF5A6480)),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _configs[status];
    final label = cfg?.$1 ?? status;
    final color = cfg?.$2 ?? AppTheme.offline;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 10,
        vertical:   large ? 8  : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: large ? 15 : 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
