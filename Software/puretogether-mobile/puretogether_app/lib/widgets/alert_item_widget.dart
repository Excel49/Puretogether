import 'package:flutter/material.dart';
import '../models/robot_data.dart';

class AlertItemWidget extends StatelessWidget {
  final AlertEntry alert;

  const AlertItemWidget({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    Color cardBg;
    Color borderColor;
    Color accentColor;
    Color iconCircleBg;
    IconData iconData;
    String titleText;

    switch (alert.type) {
      case 'DUST_HIGH':
        cardBg = const Color(0xFFFEF2F2); // Soft red
        borderColor = const Color(0xFFFECACA);
        accentColor = const Color(0xFFDC2626);
        iconCircleBg = const Color(0xFFFEE2E2);
        iconData = Icons.warning_rounded;
        titleText = 'Dust level high';
        break;
      case 'ROBOT_OFFLINE':
        cardBg = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFFECACA);
        accentColor = const Color(0xFFDC2626);
        iconCircleBg = const Color(0xFFFEE2E2);
        iconData = Icons.wifi_off_rounded;
        titleText = 'Robot offline';
        break;
      case 'BATTERY_LOW':
        cardBg = const Color(0xFFFFFBEB); // Soft amber
        borderColor = const Color(0xFFFDE68A);
        accentColor = const Color(0xFFD97706);
        iconCircleBg = const Color(0xFFFEF3C7);
        iconData = Icons.battery_alert_rounded;
        titleText = 'Battery low';
        break;
      case 'PATROL_FINISHED':
        cardBg = const Color(0xFFF0F9FF); // Soft blue
        borderColor = const Color(0xFFBAE6FD);
        accentColor = const Color(0xFF0284C7);
        iconCircleBg = const Color(0xFFE0F2FE);
        iconData = Icons.info_rounded;
        titleText = 'Patrol finished';
        break;
      case 'AIR_NORMAL':
      default:
        cardBg = const Color(0xFFF0FDF4); // Soft green
        borderColor = const Color(0xFFBBF7D0);
        accentColor = const Color(0xFF16A34A);
        iconCircleBg = const Color(0xFFDCFCE7);
        iconData = Icons.check_circle_rounded;
        titleText = 'Air quality back to normal';
        break;
    }

    final timeStr = _formatTimestamp(alert.timestamp);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconCircleBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Message & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      titleText,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: accentColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  alert.message,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475569),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    if (difference.inDays >= 1) {
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return 'Yesterday $h:$m $period';
    } else {
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $period';
    }
  }
}
