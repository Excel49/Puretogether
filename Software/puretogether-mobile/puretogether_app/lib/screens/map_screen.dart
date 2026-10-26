import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/provider.dart';
import '../providers/robot_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/map_canvas.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RobotProvider>(
      builder: (context, provider, _) {
        final data = provider.data;
        final hasMap = data.mapData != null && data.mapData!.trim().isNotEmpty;
        final steps = hasMap
            ? data.mapData!
                .split(',')
                .where((s) => s.isNotEmpty)
                .map((item) {
                  if (item.startsWith('L')) {
                    final ms = int.tryParse(item.substring(1)) ?? 0;
                    final sec = (ms / 1000.0).toStringAsFixed(1);
                    return 'Maju ${sec}s';
                  } else if (item == 'K') {
                    return 'Belok Lurus Kanan';
                  } else if (item == 'Ki') {
                    return 'Belok Lurus Kiri';
                  }
                  return item;
                })
                .toList()
            : <String>[];

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Row ────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.map_rounded,
                              color: AppTheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Live Map & Tracking',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F1E36),
                            ),
                          ),
                        ],
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: hasMap ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasMap ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
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
                                color: hasMap ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasMap ? 'Peta Aktif' : 'Default Kosong',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: hasMap ? const Color(0xFF15803D) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Map Canvas Card (Default Bersih dengan Lingkaran Robot) ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: MapCanvas(
                        mapData: data.mapData,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Info Card: Status Pemetaan ──────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: hasMap ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                hasMap ? Icons.route_rounded : Icons.info_outline_rounded,
                                color: hasMap ? AppTheme.primary : const Color(0xFF64748B),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              hasMap ? 'Rincian Peta Tersimpan' : 'Informasi Peta',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F1E36),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (hasMap) ...[
                          Text(
                            'Robot memiliki ${steps.length} segmen rute hasil Manual Mapping yang tersimpan.',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (int i = 0; i < steps.length; i++) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: steps[i].startsWith('Maju')
                                          ? const Color(0xFFEFF6FF)
                                          : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: steps[i].startsWith('Maju')
                                            ? const Color(0xFFBFDBFE)
                                            : const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: Text(
                                      steps[i],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: steps[i].startsWith('Maju')
                                            ? const Color(0xFF1D4ED8)
                                            : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                  if (i < steps.length - 1)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(Icons.arrow_forward_rounded,
                                          size: 11, color: Color(0xFF94A3B8)),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Belum ada rute lintasan yang tersimpan. Gunakan fitur Manual Mapping (Rekam Rute Manual) di menu Kontrol untuk merekam jalur.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Action Button: Sinkronkan Peta dari Robot ──────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: Color(0xFF93C5FD)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text(
                        'Sinkronkan Peta dari Robot',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        provider.fetchTelemetryOnce();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Meminta data rute peta terbaru dari robot...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
