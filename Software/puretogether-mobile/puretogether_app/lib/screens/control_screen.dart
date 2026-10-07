import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/provider.dart';
import '../providers/robot_provider.dart';
import '../theme/app_theme.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RobotProvider>(
      builder: (context, provider, _) {
        final data = provider.data;
        final isManual = data.robotMode == 'MANUAL';

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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.sports_esports_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Manual / Remote Control',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F1E36),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Robot Connection Card ────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Robot Avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.smart_toy_rounded,
                              color: AppTheme.primary,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Bot info
                        // Bot info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PureTogether Bot',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F1E36),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.fiber_manual_record,
                                    size: 10,
                                    color: data.connectionStatus == 'ONLINE'
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    data.connectionStatus == 'ONLINE' ? 'Connected (HTTP WebServer)' : 'Offline',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: data.connectionStatus == 'ONLINE'
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Signal Strength Bars
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildSignalBar(height: 8, isActive: data.connectionStatus == 'ONLINE'),
                            const SizedBox(width: 2.5),
                            _buildSignalBar(height: 12, isActive: data.connectionStatus == 'ONLINE'),
                            const SizedBox(width: 2.5),
                            _buildSignalBar(height: 16, isActive: data.connectionStatus == 'ONLINE'),
                            const SizedBox(width: 2.5),
                            _buildSignalBar(height: 20, isActive: data.connectionStatus == 'ONLINE'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Mode Toggle (Pill Switch) ────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        // Auto Mode Pill
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              provider.sendCommand('SET_AUTO');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isManual ? AppTheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: !isManual
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primary.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Auto Mode',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !isManual ? FontWeight.w800 : FontWeight.w600,
                                    color: !isManual ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Manual Mode Pill
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              provider.sendCommand('SET_MANUAL');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isManual ? AppTheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: isManual
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primary.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Manual Mode',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isManual ? FontWeight.w800 : FontWeight.w600,
                                    color: isManual ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Directional D-Pad ────────────────────────────────────
                  Center(
                    child: _buildDPad(
                      enabled: isManual,
                      onCommand: (cmd) => provider.sendCommand(cmd),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── 3 Action Buttons (Start Patrol, Pause, Return Home) ───
                  Row(
                    children: [
                      // Start Patrol (Green)
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.play_arrow_rounded,
                          label: 'Start Patrol',
                          bgColor: const Color(0xFFDCFCE7),
                          borderColor: const Color(0xFF86EFAC),
                          accentColor: const Color(0xFF15803D),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            provider.sendCommand('START_PATROL');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Pause (Orange)
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.pause_rounded,
                          label: 'Pause',
                          bgColor: const Color(0xFFFEF3C7),
                          borderColor: const Color(0xFFFDE68A),
                          accentColor: const Color(0xFFD97706),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            provider.sendCommand('PAUSE');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Return Home (Blue)
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.home_rounded,
                          label: 'Return Home',
                          bgColor: const Color(0xFFDBEAFE),
                          borderColor: const Color(0xFFBFDBFE),
                          accentColor: const Color(0xFF1D4ED8),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            provider.sendCommand('RETURN_HOME');
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Manual Recording Toggle ────────────────────────────────
                  if (isManual)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: provider.isRecordingManual ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: provider.isRecordingManual ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.fiber_manual_record_rounded,
                            color: provider.isRecordingManual ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.isRecordingManual ? 'Perekaman Peta Aktif' : 'Rekam Peta Manual',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: provider.isRecordingManual ? const Color(0xFF991B1B) : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  provider.isRecordingManual
                                      ? 'Menunggu input D-Pad. Peta: ${provider.manualMapBuffer}'
                                      : 'Durasi gerakan D-Pad akan menjadi peta robot.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: provider.isRecordingManual ? const Color(0xFFB91C1C) : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: provider.isRecordingManual,
                            onChanged: (_) => provider.toggleManualRecording(),
                            activeColor: const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                    ),
                  
                  if (isManual) const SizedBox(height: 16),

                  // ── Emote & Animations ──────────────────────────────────────
                  const Text(
                    'Emote / Interaksi',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.emoji_emotions_rounded,
                          label: 'Emote: Happy',
                          bgColor: const Color(0xFFF0FDF4),
                          borderColor: const Color(0xFFBBF7D0),
                          accentColor: const Color(0xFF16A34A),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            provider.sendCommand('EMOTE_HAPPY');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.warning_rounded,
                          label: 'Emote: Angry',
                          bgColor: const Color(0xFFFEF2F2),
                          borderColor: const Color(0xFFFECACA),
                          accentColor: const Color(0xFFDC2626),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            provider.sendCommand('EMOTE_ANGRY');
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Large Red Stop Robot Button ──────────────────────────
                  Material(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(16),
                    elevation: 2,
                    shadowColor: const Color(0xFFEF4444).withValues(alpha: 0.4),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        provider.sendCommand('EMERGENCY_STOP');
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Stop Robot',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  // ── Signal Bar Helper ──────────────────────────────────────────────────────
  Widget _buildSignalBar({required double height, required bool isActive}) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ── Directional D-Pad Widget ──────────────────────────────────────────────
  Widget _buildDPad({
    required bool enabled,
    required ValueChanged<String> onCommand,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        width: 190,
        height: 190,
        decoration: BoxDecoration(
          color: const Color(0xFFE2EDFC), // Soft pastel blue circle
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // UP Button
            Positioned(
              top: 14,
              child: _buildDPadArrow(
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        onCommand('MOVE_FORWARD');
                      }
                    : null,
              ),
            ),
            // DOWN Button
            Positioned(
              bottom: 14,
              child: _buildDPadArrow(
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        onCommand('MOVE_BACKWARD');
                      }
                    : null,
              ),
            ),
            // LEFT Button
            Positioned(
              left: 14,
              child: _buildDPadArrow(
                icon: Icons.keyboard_arrow_left_rounded,
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        onCommand('MOVE_LEFT');
                      }
                    : null,
              ),
            ),
            // RIGHT Button
            Positioned(
              right: 14,
              child: _buildDPadArrow(
                icon: Icons.keyboard_arrow_right_rounded,
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        onCommand('MOVE_RIGHT');
                      }
                    : null,
              ),
            ),
            // CENTER Button
            GestureDetector(
              onTap: enabled
                  ? () {
                      HapticFeedback.mediumImpact();
                      onCommand('STOP');
                    }
                  : null,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x331B68D2),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDPadArrow({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  // ── Action Button Helper ──────────────────────────────────────────────────
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color borderColor,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: accentColor, size: 26),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
