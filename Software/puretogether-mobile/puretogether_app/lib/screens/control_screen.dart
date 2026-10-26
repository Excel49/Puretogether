import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/provider.dart';
import '../providers/robot_provider.dart';
import '../theme/app_theme.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Auto-brake failsafe jika aplikasi diminimalkan / ada panggilan masuk saat mengemudi
      if (mounted) {
        final provider = context.read<RobotProvider>();
        provider.sendCommand('STOP');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RobotProvider>(
      builder: (context, provider, _) {
        final data = provider.data;
        final isAuto = data.robotMode == 'AUTO';
        final isIdle = data.robotMode == 'IDLE';
        final isManual = data.robotMode == 'MANUAL';
        final isSmokeDanger = provider.isSmokeDanger;

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
                              if (isSmokeDanger) ...[
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 11, color: Color(0xFFDC2626)),
                                      SizedBox(width: 3),
                                      Text(
                                        'Bahaya Asap — Kemudi Dikunci',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (isIdle) ...[
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sensors_rounded, size: 11, color: Color(0xFF16A34A)),
                                      SizedBox(width: 3),
                                      Text(
                                        'Siaga (Idle) — Aliran Data Masuk',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (isManual) ...[
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 11, color: AppTheme.primary),
                                      SizedBox(width: 3),
                                      Text(
                                        '1-Arah Prioritas Kemudi',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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

                  // ── Mode Toggle (3-Way Pill Switch: Auto | Idle | Manual) ──
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
                          child: _buildModePill(
                            label: 'Auto',
                            icon: Icons.alt_route_rounded,
                            isSelected: isAuto,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              provider.sendCommand('SET_AUTO');
                            },
                          ),
                        ),
                        // Idle Mode Pill
                        Expanded(
                          child: _buildModePill(
                            label: 'Idle',
                            icon: Icons.pause_circle_outline_rounded,
                            isSelected: isIdle,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              provider.sendCommand('SET_IDLE');
                            },
                          ),
                        ),
                        // Manual Mode Pill
                        Expanded(
                          child: _buildModePill(
                            label: 'Manual',
                            icon: Icons.sports_esports_rounded,
                            isSelected: isManual,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              provider.sendCommand('SET_MANUAL');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── TAMPILAN MODE MANUAL & IDLE ────────────────────────────
                  if (!isAuto) ...[
                    // 1. Banner Bahaya Asap (Jika asap terdeteksi, mobil dikunci dilarang bergerak)
                    if (isSmokeDanger) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDC2626),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BAHAYA ASAP TERDETEKSI (${data.dustLevel.toStringAsFixed(1)} µg/m³)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Mobil dilarang bergerak demi keselamatan! Aliran data otomatis memantau penurunan asap.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C), height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isIdle) ...[
                      // Banner Info Mode Siaga (Idle)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.sensors_rounded, color: Color(0xFF16A34A), size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Mode Siaga (Idle): Mobil diam, data sensor mengalir live ke HP.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 2. D-Pad Directional Controller (Hold-to-Move, Locked saat Bahaya Asap)
                    Center(
                      child: _buildDPad(
                        enabled: !isSmokeDanger,
                        onCommand: (cmd) => provider.sendCommand(cmd),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 2. Emote / Interaksi & Lagu Ulang Tahun
                    const Text(
                      'Emote / Interaksi Robot',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.emoji_emotions_rounded,
                            label: 'Happy',
                            bgColor: const Color(0xFFF0FDF4),
                            borderColor: const Color(0xFFBBF7D0),
                            accentColor: const Color(0xFF16A34A),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              provider.sendCommand('EMOTE_HAPPY');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.warning_rounded,
                            label: 'Angry',
                            bgColor: const Color(0xFFFEF2F2),
                            borderColor: const Color(0xFFFECACA),
                            accentColor: const Color(0xFFDC2626),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              provider.sendCommand('EMOTE_ANGRY');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.cake_rounded,
                            label: 'Lagu Ultah',
                            bgColor: const Color(0xFFFDF2F8),
                            borderColor: const Color(0xFFFBCFE8),
                            accentColor: const Color(0xFFDB2777),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              provider.sendCommand('EMOTE_BIRTHDAY');
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 3. Manual Mapping (Rekam Rute Manual tanpa Kalibrasi Infrared)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: provider.isRecordingManual ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                          width: provider.isRecordingManual ? 1.5 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: provider.isRecordingManual
                                ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: provider.isRecordingManual ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  provider.isRecordingManual ? Icons.fiber_manual_record_rounded : Icons.map_rounded,
                                  color: provider.isRecordingManual ? const Color(0xFFDC2626) : AppTheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      provider.isRecordingManual ? 'Merekam Rute Manual...' : 'Manual Mapping (Rekam Rute)',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: provider.isRecordingManual ? const Color(0xFFDC2626) : const Color(0xFF0F1E36),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      provider.isRecordingManual
                                          ? 'Kemudikan mobil (Maju / Belok Lurus). Tekan Selesai untuk kirim ke robot.'
                                          : 'Rekam jalur peta secara manual menggunakan D-Pad tanpa kalibrasi infrared.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: provider.isRecordingManual ? const Color(0xFFB91C1C) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (provider.manualMapSteps.isNotEmpty)
                                IconButton(
                                  tooltip: 'Reset Rute',
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    provider.clearManualMapBuffer();
                                  },
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                                ),
                            ],
                          ),
                          if (provider.manualMapSteps.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (int i = 0; i < provider.manualMapSteps.length; i++) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: provider.manualMapSteps[i].startsWith('Maju')
                                            ? const Color(0xFFEFF6FF)
                                            : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: provider.manualMapSteps[i].startsWith('Maju')
                                              ? const Color(0xFFBFDBFE)
                                              : const Color(0xFFFDE68A),
                                        ),
                                      ),
                                      child: Text(
                                        provider.manualMapSteps[i],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: provider.manualMapSteps[i].startsWith('Maju')
                                              ? const Color(0xFF1D4ED8)
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                    if (i < provider.manualMapSteps.length - 1)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: provider.isRecordingManual ? const Color(0xFF16A34A) : AppTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: Icon(
                                provider.isRecordingManual ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded,
                                size: 18,
                              ),
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                provider.toggleManualRecording();
                              },
                              label: Text(
                                provider.isRecordingManual ? 'Selesai & Simpan Rute ke Robot' : 'Mulai Rekam Rute Manual',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],

                  // ── TAMPILAN MODE AUTO ────────────────────────────────────
                  if (isAuto) ...[
                    // 1. Banner Info Patroli Otomatis
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Patroli Otomatis (Line Follower)',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Letakkan robot di garis start. Robot akan menghitung mundur 3 detik diiringi buzzer sebelum jalan.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6), height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. Tiga Tombol Navigasi Patroli
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

                    const SizedBox(height: 16),

                    // 3. Tombol Besar Stop Robot (Merah)
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

                    const SizedBox(height: 18),

                    // 4. Jejak Rute Peta (Breadcrumbs)
                    if (provider.manualMapSteps.isNotEmpty || (data.mapData != null && data.mapData!.isNotEmpty)) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.route_rounded, size: 16, color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Jejak Rute Lintasan (${provider.manualMapSteps.length} langkah)',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (int i = 0; i < provider.manualMapSteps.length; i++) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: provider.manualMapSteps[i].startsWith('Maju')
                                            ? const Color(0xFFEFF6FF)
                                            : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: provider.manualMapSteps[i].startsWith('Maju')
                                              ? const Color(0xFFBFDBFE)
                                              : const Color(0xFFFDE68A),
                                        ),
                                      ),
                                      child: Text(
                                        provider.manualMapSteps[i],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: provider.manualMapSteps[i].startsWith('Maju')
                                              ? const Color(0xFF1D4ED8)
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                    if (i < provider.manualMapSteps.length - 1)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],

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

  // ── Directional D-Pad Widget (Hold-to-Move & Smooth Belok Lurus) ──────────
  Widget _buildDPad({
    required bool enabled,
    required ValueChanged<String> onCommand,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        width: 210,
        height: 210,
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
            // UP-LEFT Button (Belok Lurus Kiri - Tanpa Berhenti Dahulu)
            Positioned(
              top: 30,
              left: 30,
              child: _HoldDPadButton(
                icon: Icons.turn_slight_left_rounded,
                enabled: enabled,
                command: 'MOVE_FORWARD_LEFT',
                onCommand: onCommand,
              ),
            ),
            // UP-RIGHT Button (Belok Lurus Kanan - Tanpa Berhenti Dahulu)
            Positioned(
              top: 30,
              right: 30,
              child: _HoldDPadButton(
                icon: Icons.turn_slight_right_rounded,
                enabled: enabled,
                command: 'MOVE_FORWARD_RIGHT',
                onCommand: onCommand,
              ),
            ),
            // UP Button (Maju - Hold to Move, Release to Stop)
            Positioned(
              top: 12,
              child: _HoldDPadButton(
                icon: Icons.keyboard_arrow_up_rounded,
                enabled: enabled,
                command: 'MOVE_FORWARD',
                onCommand: onCommand,
              ),
            ),
            // DOWN Button (Mundur - Hold to Move, Release to Stop)
            Positioned(
              bottom: 12,
              child: _HoldDPadButton(
                icon: Icons.keyboard_arrow_down_rounded,
                enabled: enabled,
                command: 'MOVE_BACKWARD',
                onCommand: onCommand,
              ),
            ),
            // LEFT Button (Belok Kiri Tajam sambil Maju)
            Positioned(
              left: 12,
              child: _HoldDPadButton(
                icon: Icons.keyboard_arrow_left_rounded,
                enabled: enabled,
                command: 'MOVE_LEFT',
                onCommand: onCommand,
              ),
            ),
            // RIGHT Button (Belok Kanan Tajam sambil Maju)
            Positioned(
              right: 12,
              child: _HoldDPadButton(
                icon: Icons.keyboard_arrow_right_rounded,
                enabled: enabled,
                command: 'MOVE_RIGHT',
                onCommand: onCommand,
              ),
            ),
            // CENTER Button (Manual Tap Stop)
            GestureDetector(
              onTap: enabled
                  ? () {
                      HapticFeedback.mediumImpact();
                      onCommand('EMERGENCY_STOP');
                    }
                  : null,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: enabled ? AppTheme.primary : const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (enabled ? const Color(0xFF1B68D2) : const Color(0xFFEF4444)).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: enabled
                      ? Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        )
                      : const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mode Pill Widget Helper (Auto | Idle | Manual) ─────────────────────────
  Widget _buildModePill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
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

// ── Hold-to-Move D-Pad Button Widget ─────────────────────────────────────────
class _HoldDPadButton extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final String command;
  final ValueChanged<String> onCommand;

  const _HoldDPadButton({
    required this.icon,
    required this.enabled,
    required this.command,
    required this.onCommand,
  });

  @override
  State<_HoldDPadButton> createState() => _HoldDPadButtonState();
}

class _HoldDPadButtonState extends State<_HoldDPadButton> {
  bool _isPressed = false;

  void _startHolding() {
    if (!widget.enabled || _isPressed) return;
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);

    // Kirim 1x perintah gerak seketika saat tombol ditekan (tanpa spam timer berulang!)
    widget.onCommand(widget.command);
  }

  void _stopHolding() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    HapticFeedback.lightImpact();

    // Berhenti seketika saat jari dilepas
    widget.onCommand('STOP');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startHolding(),
      onTapUp: (_) => _stopHolding(),
      onTapCancel: () => _stopHolding(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _isPressed ? const Color(0xFF1550A5) : AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: _isPressed ? 0.45 : 0.25),
              blurRadius: _isPressed ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          widget.icon,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}
