import 'package:flutter/material.dart';
import '../providers/provider.dart';
import '../providers/robot_provider.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RobotProvider>(
      builder: (context, provider, _) {
        final data = provider.data;
        final isOnline = data.connectionStatus == 'ONLINE';

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Row ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                    topRight: Radius.circular(4),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.eco_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'PureTogether',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0C4A6E),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Air Quality Robot Monitor',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Green Pill Badge: "Robot Online"
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isOnline
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline ? 'Robot Online' : 'Robot Offline',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isOnline
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── Air Quality Hero Card ────────────────────────────────
                  _buildAirQualityHeroCard(data.airStatus, data.dustLevel),

                  const SizedBox(height: 16),

                  // ── 2x2 Metric Cards Grid ────────────────────────────────
                  Row(
                    children: [
                      // Dust Level Card
                      Expanded(
                        child: _buildMetricCard(
                          iconWidget: _buildDustParticlesIcon(),
                          label: 'Dust Level',
                          value: '${data.dustLevel.toStringAsFixed(0)} µg/m³',
                          subtitle: _getDustStatusLabel(data.dustLevel),
                          subtitleColor: _getDustStatusColor(data.dustLevel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Battery Card
                      Expanded(
                        child: _buildMetricCard(
                          iconWidget: _buildBatteryIcon(data.batteryPercent),
                          label: 'Battery',
                          value: '${data.batteryPercent}%',
                          subtitle: '~ ${_getBatteryHours(data.batteryPercent)} hrs',
                          subtitleColor: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // Robot Status Card
                      Expanded(
                        child: _buildMetricCard(
                          iconWidget: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.smart_toy_rounded,
                              color: Color(0xFF0284C7),
                              size: 20,
                            ),
                          ),
                          label: 'Robot Status',
                          value: data.robotMode == 'AUTO' ? 'Patrol' : 'Manual',
                          subtitle: data.robotMode == 'AUTO'
                              ? 'Running routine'
                              : 'Manual control',
                          subtitleColor: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Current Line Card
                      Expanded(
                        child: _buildMetricCard(
                          iconWidget: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.alt_route_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                          ),
                          label: 'Current Line',
                          value: 'Line ${data.currentLine ?? 'B'}',
                          subtitle: data.robotMode == 'AUTO'
                              ? 'Auto following'
                              : 'Standby',
                          subtitleColor: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── Recent Alert Section ─────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Alert',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F1E36),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          // Tab switch to Alerts can be performed if needed
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Orange-tinted Recent Alert Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB), // Soft warm amber tint
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFD97706),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dust level slightly high',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Dust at 85 µg/m³ (near threshold)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF78350F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          '10:24 AM',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Air Quality Hero Card Builder ──────────────────────────────────────────
  Widget _buildAirQualityHeroCard(String airStatus, double dustLevel) {
    Color cardBg;
    Color borderColor;
    Color statusColor;
    Color iconCircleBg;
    String statusTitle;
    String statusDesc;

    if (airStatus == 'POOR' || dustLevel >= 75) {
      cardBg = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
      statusColor = const Color(0xFFDC2626);
      iconCircleBg = const Color(0xFFFEE2E2);
      statusTitle = 'Poor';
      statusDesc = 'Air quality is hazardous';
    } else if (airStatus == 'WARNING' || dustLevel >= 35) {
      cardBg = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFDE68A);
      statusColor = const Color(0xFFD97706);
      iconCircleBg = const Color(0xFFFEF3C7);
      statusTitle = 'Moderate';
      statusDesc = 'Acceptable air quality';
    } else {
      cardBg = const Color(0xFFF0FDF4); // Soft mint green
      borderColor = const Color(0xFFBBF7D0);
      statusColor = const Color(0xFF16A34A); // Emerald green
      iconCircleBg = const Color(0xFFDCFCE7);
      statusTitle = 'Good';
      statusDesc = 'Clean and healthy air';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Leaf icon circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconCircleBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco_rounded,
              color: statusColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Air Quality',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusDesc,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Chevron
          Icon(
            Icons.chevron_right_rounded,
            color: statusColor,
            size: 28,
          ),
        ],
      ),
    );
  }

  // ── 2x2 Metric Card Widget ────────────────────────────────────────────────
  Widget _buildMetricCard({
    required Widget iconWidget,
    required String label,
    required String value,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget,
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F1E36),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDustParticlesIcon() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(
          Icons.grain_rounded,
          color: Color(0xFF2563EB),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildBatteryIcon(int percent) {
    Color batteryColor;
    if (percent <= 20) {
      batteryColor = const Color(0xFFEF4444);
    } else if (percent <= 50) {
      batteryColor = const Color(0xFFF59E0B);
    } else {
      batteryColor = const Color(0xFF10B981);
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: batteryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(
          Icons.battery_5_bar_rounded,
          color: batteryColor,
          size: 22,
        ),
      ),
    );
  }

  String _getDustStatusLabel(double dust) {
    if (dust < 35) return 'Normal';
    if (dust < 75) return 'Moderate';
    return 'High';
  }

  Color _getDustStatusColor(double dust) {
    if (dust < 35) return const Color(0xFF10B981);
    if (dust < 75) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _getBatteryHours(int percent) {
    final hrs = (percent / 100 * 3.2).toStringAsFixed(1);
    return hrs;
  }
}
