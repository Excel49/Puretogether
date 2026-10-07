import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/provider.dart';
import '../providers/robot_provider.dart';
import '../services/http_robot_service.dart';
import '../theme/app_theme.dart';

/// Halaman Terminal Live Debugger untuk memonitor paket data HTTP
class HttpDebugScreen extends StatefulWidget {
  const HttpDebugScreen({super.key});

  @override
  State<HttpDebugScreen> createState() => _HttpDebugScreenState();
}

class _HttpDebugScreenState extends State<HttpDebugScreen> {
  final ScrollController _scrollController = ScrollController();
  final bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RobotProvider>(
      builder: (context, provider, _) {
        final logs = provider.httpLogs;
        final isConnected = provider.data.connectionStatus == 'ONLINE';

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return Scaffold(
          backgroundColor: const Color(0xFF090D16),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live HTTP Debug Monitor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Target: http://${provider.settings.robotIp}:${provider.settings.robotPort}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Bersihkan Log',
                icon: const Icon(Icons.delete_sweep_rounded,
                    color: Color(0xFF94A3B8)),
                onPressed: () {
                  provider.clearHttpLogs();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Log HTTP dibersihkan.')),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // ── Top Stats Bar ───────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFF0F172A),
                child: Row(
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? const Color(0x2610B981)
                            : const Color(0x26EF4444),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isConnected
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isConnected ? 'ONLINE' : 'POLLING / ERROR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isConnected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Counters
                    _buildStatPill('IN: ${provider.httpRequestsReceived}',
                        const Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    _buildStatPill('OUT: ${provider.httpRequestsSent}',
                        const Color(0xFFA78BFA)),
                  ],
                ),
              ),

              // ── Terminal Console Area ───────────────────────────────────
              Expanded(
                child: logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.terminal_rounded,
                              size: 48,
                              color: Color(0xFF334155),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Menunggu data HTTP...',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pastikan HP tersambung ke Wi-Fi Hotspot ESP-01.\nPolling aktif pada ${provider.settings.robotIp}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Item terbaru di bagian bawah
                        padding: const EdgeInsets.all(12),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return _buildLogItem(log);
                        },
                      ),
              ),

              // ── Bottom Action Toolbar ───────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Button 1: Kirim Test /start-map
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text(
                              'Kirim /start-map',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () async {
                              final ok = await provider.startCalibration();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  backgroundColor: ok
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  content: Text(ok
                                      ? 'Terkirim via HTTP!'
                                      : 'Gagal kirim HTTP request'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Button 2: Simulasi Paket Masuk (Uji UI)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(
                                  color: Color(0xFF0284C7), width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.play_circle_outline_rounded,
                                size: 16),
                            label: const Text(
                              'Simulasi Inbound',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              final sample = jsonEncode({
                                "status": "Aman",
                                "debu_value": 45.23,
                                "battery_voltage": 12.0,
                                "map_data": "L4500,K,L2000,Ki,",
                              });
                              provider.simulateHttpPacket(sample);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLogItem(HttpLogEntry log) {
    Color dirColor;
    switch (log.direction) {
      case 'IN':
      case 'IN (SIM)':
        dirColor = const Color(0xFF34D399); // Emerald
        break;
      case 'OUT':
        dirColor = const Color(0xFF60A5FA); // Blue
        break;
      case 'ERR':
        dirColor = const Color(0xFFF87171); // Red
        break;
      default:
        dirColor = const Color(0xFFFBBF24); // Amber
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1525),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              log.isError ? const Color(0x40EF4444) : const Color(0xFF1E293B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: dirColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.direction,
                  style: TextStyle(
                    color: dirColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.source,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                log.timeFormatted,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: log.payload));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Disalin ke clipboard!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: const Icon(Icons.copy_rounded,
                    size: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            log.payload,
            style: TextStyle(
              color: log.isError
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFF1F5F9),
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
