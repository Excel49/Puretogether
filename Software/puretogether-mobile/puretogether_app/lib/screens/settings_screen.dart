import 'package:flutter/material.dart';
import '../providers/provider.dart';
import '../providers/robot_provider.dart';
import '../theme/app_theme.dart';
import 'http_debug_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _dustThreshold = 100;
  bool _airQualityNotifications = true;
  bool _alertNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<RobotProvider>(
      builder: (context, provider, _) {
        final isConnected = provider.data.connectionStatus == 'ONLINE';

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
                          Icons.settings_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F1E36),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Group 1: Robot Connection ───────────────────────────
                  _buildSectionTitle('Robot Connection'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _showUdpConfigDialog(context, provider),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFE2E8F0), width: 1.2),
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
                          // Robot thumbnail
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.smart_toy_rounded,
                                color: AppTheme.primary,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Titles
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PureTogether Bot',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F1E36),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'HTTP: ${provider.settings.robotIp}:${provider.settings.robotPort}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Connected Pill status + chevron
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isConnected
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isConnected ? 'Connected' : 'Offline',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isConnected
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF94A3B8),
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Group 2: Monitoring Settings ────────────────────────
                  _buildSectionTitle('Monitoring Settings'),
                  const SizedBox(height: 8),
                  _buildGroupCard([
                    // Dust Threshold Item
                    _buildSettingsRow(
                      icon: Icons.grain_rounded,
                      title: 'Dust Threshold',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_dustThreshold µg/m³',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ],
                      ),
                      onTap: () => _showDustThresholdDialog(context),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Air Quality Notifications
                    _buildSettingsRow(
                      icon: Icons.air_rounded,
                      title: 'Air Quality Notifications',
                      trailing: Switch.adaptive(
                        value: _airQualityNotifications,
                        activeColor: AppTheme.primary,
                        onChanged: (val) =>
                            setState(() => _airQualityNotifications = val),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Alert Notifications
                    _buildSettingsRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Alert Notifications',
                      trailing: Switch.adaptive(
                        value: _alertNotifications,
                        activeColor: AppTheme.primary,
                        onChanged: (val) =>
                            setState(() => _alertNotifications = val),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Group 3: Map & Navigation ───────────────────────────
                  _buildSectionTitle('Map & Navigation'),
                  const SizedBox(height: 8),
                  _buildGroupCard([
                    _buildSettingsRow(
                      icon: Icons.map_outlined,
                      title: 'Map Configuration',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onTap: () {},
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildSettingsRow(
                      icon: Icons.tune_rounded,
                      title: 'Line Settings',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onTap: () {},
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Group 4: Device Information ─────────────────────────
                  _buildSectionTitle('Device Information'),
                  const SizedBox(height: 8),
                  _buildGroupCard([
                    _buildSettingsRow(
                      icon: Icons.info_outline_rounded,
                      title: 'About Robot',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onTap: () {},
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildSettingsRow(
                      icon: Icons.terminal_rounded,
                      title: 'Live HTTP Debug Monitor',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Terminal',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HttpDebugScreen()),
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Group 5: App Information ────────────────────────────
                  _buildSectionTitle('App Information'),
                  const SizedBox(height: 8),
                  _buildGroupCard([
                    _buildSettingsRow(
                      icon: Icons.info_rounded,
                      title: 'App Version',
                      trailing: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'v1.0.0',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ],
                      ),
                      onTap: () {},
                    ),
                  ]),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildGroupCard(List<Widget> children) {
    return Container(
      width: double.infinity,
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
        children: children,
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0F1E36), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F1E36),
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  void _showDustThresholdDialog(BuildContext context) {
    double tempVal = _dustThreshold.toDouble();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Text(
                'Set Dust Threshold',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tempVal.round()} µg/m³',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: tempVal,
                    min: 25,
                    max: 200,
                    divisions: 35,
                    activeColor: AppTheme.primary,
                    onChanged: (val) => setDlgState(() => tempVal = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() => _dustThreshold = tempVal.round());
                    Navigator.pop(ctx);
                  },
                  child:
                      const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUdpConfigDialog(BuildContext context, RobotProvider provider) {
    final ipCtrl = TextEditingController(text: provider.settings.robotIp);
    final portCtrl =
        TextEditingController(text: provider.settings.robotPort.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.wifi_tethering_rounded,
                  color: AppTheme.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Robot HTTP WebServer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Konfigurasi IP ESP-01 Hotspot dan Port UDP untuk komunikasi langsung dengan STM32:',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ipCtrl,
                decoration: const InputDecoration(
                  labelText: 'Robot IP (ESP-01 AP)',
                  hintText: '192.168.4.1',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'HTTP Port',
                  hintText: '80',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.terminal_rounded, size: 16),
                  label: const Text('Buka Live Debug Monitor'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HttpDebugScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final port = int.tryParse(portCtrl.text.trim()) ?? 80;
                final ip = ipCtrl.text.trim();
                provider.updateSettings(
                  provider.settings.copyWith(
                    robotIp: ip.isNotEmpty ? ip : '192.168.4.1',
                    robotPort: port,
                  ),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1B68D2),
                    content: Text('Menghubungkan HTTP ke $ip:$port...'),
                  ),
                );
              },
              child: const Text('Simpan & Hubungkan',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
