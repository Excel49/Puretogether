import 'package:flutter/material.dart';
import '../models/robot_data.dart';
import '../providers/provider.dart';
import '../providers/robot_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/alert_item_widget.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _selectedFilter = 'All';

  final List<String> _filters = const ['All', 'Warnings', 'Errors', 'Info'];

  @override
  Widget build(BuildContext context) {
    return Consumer<RobotProvider>(
      builder: (context, provider, _) {
        final allAlerts = provider.alerts.isNotEmpty
            ? provider.alerts
            : _wireframeDefaultAlerts();

        final filteredAlerts = allAlerts.where((a) {
          if (_selectedFilter == 'All') return true;
          if (_selectedFilter == 'Warnings') return a.type == 'BATTERY_LOW' || a.type == 'DUST_HIGH';
          if (_selectedFilter == 'Errors') return a.type == 'ROBOT_OFFLINE';
          if (_selectedFilter == 'Info') return a.type == 'PATROL_FINISHED' || a.type == 'AIR_NORMAL';
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Row ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Alerts & History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F1E36),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Filter Chips Row ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: _filters.map((f) {
                      final isSelected = _selectedFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFilter = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : const Color(0xFFEFF3F8),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Alerts List ──────────────────────────────────────────
                Expanded(
                  child: filteredAlerts.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada notifikasi dalam filter ini',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          itemCount: filteredAlerts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => AlertItemWidget(alert: filteredAlerts[i]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static List<AlertEntry> _wireframeDefaultAlerts() {
    final now = DateTime.now();
    return [
      AlertEntry(
        id: '1',
        type: 'DUST_HIGH',
        timestamp: DateTime(now.year, now.month, now.day, 10, 24),
        message: 'Dust sensor reading above threshold (120 µg/m³)',
        dustLevel: 120,
      ),
      AlertEntry(
        id: '2',
        type: 'ROBOT_OFFLINE',
        timestamp: DateTime(now.year, now.month, now.day, 9, 18),
        message: 'Lost connection with robot',
      ),
      AlertEntry(
        id: '3',
        type: 'BATTERY_LOW',
        timestamp: DateTime(now.year, now.month, now.day, 8, 47),
        message: 'Battery at 20%. Please recharge.',
        batteryPercent: 20,
      ),
      AlertEntry(
        id: '4',
        type: 'PATROL_FINISHED',
        timestamp: DateTime(now.year, now.month, now.day - 1, 17, 32),
        message: 'Line B patrol completed successfully',
      ),
      AlertEntry(
        id: '5',
        type: 'AIR_NORMAL',
        timestamp: DateTime(now.year, now.month, now.day - 1, 14, 14),
        message: 'Dust level is now 18 µg/m³',
        dustLevel: 18,
      ),
    ];
  }
}
