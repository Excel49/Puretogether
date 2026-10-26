import 'package:flutter/material.dart';
import '../models/robot_data.dart';
import '../providers/provider.dart';
import '../providers/robot_provider.dart';
import '../theme/app_theme.dart';

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

                  // ── Group: Sensor Testing & Simulasi (Bypass Sensor) ─────
                  _buildSectionTitle('Sensor Testing & Simulasi (Bypass Sensor)'),
                  const SizedBox(height: 8),
                  _buildGroupCard([
                    _buildSettingsRow(
                      icon: Icons.science_rounded,
                      title: 'Skenario Uji Sensor Debu',
                      subtitle: provider.isScenarioActive
                          ? 'Simulasi Aktif: ${_getActiveScenarioTitle(provider.activeScenarioId)}'
                          : 'Hardware Sensor Fisik Aktif (Default)',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: provider.isScenarioActive
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: provider.isScenarioActive
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              provider.isScenarioActive ? 'SIMULASI' : 'REAL HW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: provider.isScenarioActive
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ],
                      ),
                      onTap: () => _showTestScenariosSheet(context, provider),
                    ),
                    if (provider.isScenarioActive) ...[
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Data sensor sedang dibypass dengan data skenario pengujian.',
                                style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                provider.clearTestScenario();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Simulasi dihentikan. Kembali ke sensor fisik.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 20),

                  // ── Group 3: Device Information ─────────────────────────
                  _buildSectionTitle('Device Information'),
                  const SizedBox(height: 8),
                  _buildGroupCard([
                    _buildSettingsRow(
                      icon: Icons.info_outline_rounded,
                      title: 'About Robot',
                      subtitle: 'PureTogether • STM32 Bluepill & ESP-01',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'PureTogether',
                          applicationVersion: '2.0.0 (STM32 + ESP8266)',
                          applicationLegalese: 'Air Quality Patrol Robot with Smart Mapping',
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
    String? subtitle,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F1E36),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  String _getActiveScenarioTitle(String? id) {
    if (id == null) return 'Hardware Fisik';
    try {
      final s = predefinedTestScenarios.firstWhere((item) => item.id == id);
      return s.name;
    } catch (_) {
      return id;
    }
  }

  void _showTestScenariosSheet(BuildContext context, RobotProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.science_rounded, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Skenario Pengujian Sensor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F1E36),
                          ),
                        ),
                        Text(
                          'Bypass sensor fisik jika kabel/wiring bermasalah',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: predefinedTestScenarios.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final scenario = predefinedTestScenarios[idx];
                    final isSelected = provider.activeScenarioId == scenario.id;

                    Color badgeColor;
                    Color badgeTextColor;
                    IconData icon;
                    if (scenario.id == 'clean_air') {
                      badgeColor = const Color(0xFFDCFCE7);
                      badgeTextColor = const Color(0xFF15803D);
                      icon = Icons.eco_rounded;
                    } else if (scenario.id == 'warning_air') {
                      badgeColor = const Color(0xFFFEF3C7);
                      badgeTextColor = const Color(0xFFB45309);
                      icon = Icons.warning_amber_rounded;
                    } else if (scenario.id == 'danger_air') {
                      badgeColor = const Color(0xFFFEE2E2);
                      badgeTextColor = const Color(0xFFB91C1C);
                      icon = Icons.error_outline_rounded;
                    } else if (scenario.id == 'low_battery') {
                      badgeColor = const Color(0xFFFFEDD5);
                      badgeTextColor = const Color(0xFFC2410C);
                      icon = Icons.battery_alert_rounded;
                    } else {
                      badgeColor = const Color(0xFFDBEAFE);
                      badgeTextColor = const Color(0xFF1D4ED8);
                      icon = Icons.map_rounded;
                    }

                    return InkWell(
                      onTap: () {
                        provider.applyTestScenario(scenario);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.primary,
                            content: Text('Skenario "${scenario.name}" diaktifkan!'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: badgeTextColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        scenario.name,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? AppTheme.primary : const Color(0xFF0F1E36),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${scenario.dustLevel.toInt()} µg/m³',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: badgeTextColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    scenario.subtitle,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20)
                            else
                              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (provider.isScenarioActive)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                    label: const Text('Reset ke Hardware Nyata (Bypass Mati)', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () {
                      provider.clearTestScenario();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bypass dinonaktifkan. Menggunakan sensor fisik asli.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
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
                  hintText: '8888',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                final port = int.tryParse(portCtrl.text.trim()) ?? 8888;
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
