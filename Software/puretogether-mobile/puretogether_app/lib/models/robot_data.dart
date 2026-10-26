/// Model data robot yang mencakup telemetri dari STM32 + ESP-01 via UDP
class RobotData {
  final String airStatus; // GOOD | WARNING | POOR
  final double dustLevel; // µg/m³
  final int batteryPercent;
  final double batteryVoltage; // V
  final String robotMode; // AUTO | MANUAL | ALERT | CALIBRATION
  final String? currentLine; // A | B | C
  final String? checkpoint; // A-1, B-3, dst.
  final String connectionStatus; // ONLINE | OFFLINE
  final String? mapData; // Rekaman durasi & belokan: "L4500,K,L2000,Ki,"
  final String? rawStatus; // "Aman" | "Bahaya"
  final bool isWaitingStart; // Status robot menunggu garis start/finish saat kalibrasi
  final DateTime lastUpdated;

  const RobotData({
    required this.airStatus,
    required this.dustLevel,
    required this.batteryPercent,
    required this.batteryVoltage,
    required this.robotMode,
    this.currentLine,
    this.checkpoint,
    required this.connectionStatus,
    this.mapData,
    this.rawStatus,
    this.isWaitingStart = false,
    required this.lastUpdated,
  });

  factory RobotData.initial() => RobotData(
        airStatus: 'GOOD',
        dustLevel: 12.0,
        batteryPercent: 82,
        batteryVoltage: 7.4,
        robotMode: 'IDLE', // Default IDLE (siaga) agar data sensor langsung mengalir ke Flutter
        currentLine: 'B',
        checkpoint: 'B-3',
        connectionStatus: 'OFFLINE',
        mapData: '', // Default kosong (hanya tampil tanda bulat robot)
        rawStatus: 'Aman',
        isWaitingStart: false,
        lastUpdated: DateTime.now(),
      );

  /// Konversi voltase baterai (2S 7.4V Li-ion: 2x 3.7V) ke persentase 0..100%
  /// Penuh: 8.4V (4.2V x 2), Nominal: 7.4V, Batas Kosong/Cutoff: 6.2V (3.1V x 2)
  static int calculateBatteryPercent(double voltage) {
    if (voltage <= 0) return 0;
    if (voltage >= 8.4) return 100;
    if (voltage <= 6.2) return 0;
    final percent = ((voltage - 6.2) / (8.4 - 6.2)) * 100;
    return percent.clamp(0, 100).round();
  }

  /// Parser untuk format JSON Hardware STM32 + ESP-01 via HTTP:
  /// {
  ///   "status": "Aman",
  ///   "mode": "Remote Manual",
  ///   "debu_value": 45.2,
  ///   "battery_voltage": 7.4,
  ///   "wait_start": 0,
  ///   "map_data": "L4500,K,L2000,Ki,"
  /// }
  factory RobotData.fromHardwareJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString() ?? 'Aman';
    final rawMode = json['mode']?.toString() ?? '';
    final debuVal = (json['debu_value'] as num?)?.toDouble() ?? 0.0;
    final voltage = (json['battery_voltage'] as num?)?.toDouble() ?? 7.4;
    final mapDataStr = json['map_data']?.toString();
    final waitStartVal = json['wait_start'];
    final bool isWaitingStart =
        waitStartVal == 1 || waitStartVal == '1' || waitStartVal == true;

    // Tentukan airStatus berdasarkan status STM32 atau nilai debu
    String airStatus;
    if (rawStatus.toLowerCase() == 'bahaya' || debuVal > 100.0) {
      airStatus = 'POOR';
    } else if (debuVal > 75.0) {
      airStatus = 'WARNING';
    } else {
      airStatus = 'GOOD';
    }

    // Tentukan robotMode dari respons firmware
    String mode;
    if (airStatus == 'POOR') {
      mode = 'ALERT';
    } else if (rawMode.toLowerCase().contains('idle')) {
      mode = 'IDLE';
    } else if (rawMode.toLowerCase().contains('manual')) {
      mode = 'MANUAL';
    } else {
      mode = 'AUTO';
    }

    return RobotData(
      airStatus: airStatus,
      dustLevel: debuVal,
      batteryPercent: calculateBatteryPercent(voltage),
      batteryVoltage: voltage,
      robotMode: mode,
      currentLine: 'B',
      checkpoint: 'B-3',
      connectionStatus: 'ONLINE',
      mapData: mapDataStr,
      rawStatus: rawStatus,
      isWaitingStart: isWaitingStart,
      lastUpdated: DateTime.now(),
    );
  }

  /// Parser fallback jika data yang dikirim adalah string CSV: DATA,[Status],[Debu],[Baterai]
  factory RobotData.fromHardwareCsv(String csv) {
    final parts = csv.split(',');
    final rawStatus = parts.length > 1 ? parts[1].trim() : 'Aman';
    final debuVal =
        parts.length > 2 ? double.tryParse(parts[2].trim()) ?? 0.0 : 0.0;
    final voltage =
        parts.length > 3 ? double.tryParse(parts[3].trim()) ?? 7.4 : 7.4;

    String airStatus;
    if (rawStatus.toLowerCase() == 'bahaya' || debuVal > 100.0) {
      airStatus = 'POOR';
    } else if (debuVal > 75.0) {
      airStatus = 'WARNING';
    } else {
      airStatus = 'GOOD';
    }

    return RobotData(
      airStatus: airStatus,
      dustLevel: debuVal,
      batteryPercent: calculateBatteryPercent(voltage),
      batteryVoltage: voltage,
      robotMode: (airStatus == 'POOR') ? 'ALERT' : 'AUTO',
      currentLine: 'B',
      checkpoint: 'B-3',
      connectionStatus: 'ONLINE',
      rawStatus: rawStatus,
      isWaitingStart: false,
      lastUpdated: DateTime.now(),
    );
  }

  factory RobotData.fromJson(Map<String, dynamic> json) => RobotData(
        airStatus: json['air_status'] ?? 'GOOD',
        dustLevel: (json['dust_level'] ?? 0.0).toDouble(),
        batteryPercent: json['battery_percent'] ?? 0,
        batteryVoltage: (json['battery_voltage'] ?? 0.0).toDouble(),
        robotMode: json['robot_mode'] ?? 'AUTO',
        currentLine: json['current_line'],
        checkpoint: json['checkpoint'],
        connectionStatus: json['connection_status'] ?? 'OFFLINE',
        mapData: json['map_data'],
        rawStatus: json['status'],
        isWaitingStart: json['wait_start'] == 1 || json['wait_start'] == true,
        lastUpdated: DateTime.now(),
      );

  RobotData copyWith({
    String? airStatus,
    double? dustLevel,
    int? batteryPercent,
    double? batteryVoltage,
    String? robotMode,
    String? currentLine,
    String? checkpoint,
    String? connectionStatus,
    String? mapData,
    String? rawStatus,
    bool? isWaitingStart,
    DateTime? lastUpdated,
  }) =>
      RobotData(
        airStatus: airStatus ?? this.airStatus,
        dustLevel: dustLevel ?? this.dustLevel,
        batteryPercent: batteryPercent ?? this.batteryPercent,
        batteryVoltage: batteryVoltage ?? this.batteryVoltage,
        robotMode: robotMode ?? this.robotMode,
        currentLine: currentLine ?? this.currentLine,
        checkpoint: checkpoint ?? this.checkpoint,
        connectionStatus: connectionStatus ?? this.connectionStatus,
        mapData: mapData ?? this.mapData,
        rawStatus: rawStatus ?? this.rawStatus,
        isWaitingStart: isWaitingStart ?? this.isWaitingStart,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

class AlertEntry {
  final String id;
  final String
      type; // DUST_HIGH | BATTERY_LOW | ROBOT_OFFLINE | PATROL_FINISHED | AIR_NORMAL
  final DateTime timestamp;
  final String message;
  final double? dustLevel;
  final int? batteryPercent;

  const AlertEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.message,
    this.dustLevel,
    this.batteryPercent,
  });
}

class RobotSettings {
  final String robotIp;
  final int robotPort;
  final double dustThreshold;
  final int batteryLowThreshold;
  final bool notificationsEnabled;
  final bool isUdpEnabled;

  const RobotSettings({
    this.robotIp = '192.168.4.1',
    this.robotPort = 8888,
    this.dustThreshold = 100,
    this.batteryLowThreshold = 20,
    this.notificationsEnabled = true,
    this.isUdpEnabled = true,
  });

  RobotSettings copyWith({
    String? robotIp,
    int? robotPort,
    double? dustThreshold,
    int? batteryLowThreshold,
    bool? notificationsEnabled,
    bool? isUdpEnabled,
  }) =>
      RobotSettings(
        robotIp: robotIp ?? this.robotIp,
        robotPort: robotPort ?? this.robotPort,
        dustThreshold: dustThreshold ?? this.dustThreshold,
        batteryLowThreshold: batteryLowThreshold ?? this.batteryLowThreshold,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        isUdpEnabled: isUdpEnabled ?? this.isUdpEnabled,
      );
}

// Checkpoint definitions per line
const Map<String, List<String>> lineCheckpoints = {
  'A': ['A-1', 'A-2', 'A-3', 'A-4', 'A-5'],
  'B': ['B-1', 'B-2', 'B-3', 'B-4'],
  'C': ['C-1', 'C-2', 'C-3'],
};

/// Model Skenario Pengujian (untuk simulasi kondisi sensor jika wiring bermasalah)
class TestScenario {
  final String id;
  final String name;
  final String subtitle;
  final double dustLevel;
  final String airStatus; // 'GOOD' | 'WARNING' | 'POOR'
  final String rawStatus; // 'Aman' | 'Bahaya'
  final double batteryVoltage;
  final int batteryPercent;
  final String robotMode; // 'AUTO' | 'MANUAL' | 'ALERT' | 'CALIBRATION'
  final String? currentLine;
  final String? checkpoint;
  final String? mapData;

  const TestScenario({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.dustLevel,
    required this.airStatus,
    required this.rawStatus,
    required this.batteryVoltage,
    required this.batteryPercent,
    required this.robotMode,
    this.currentLine = 'B',
    this.checkpoint = 'B-2',
    this.mapData,
  });
}

const List<TestScenario> predefinedTestScenarios = [
  TestScenario(
    id: 'clean_air',
    name: 'Skenario 1: Udara Bersih & Normal',
    subtitle: 'Debu 14.5 µg/m³ • Status Aman (Hijau) • Baterai 8.2V (90%)',
    dustLevel: 14.5,
    airStatus: 'GOOD',
    rawStatus: 'Aman',
    batteryVoltage: 8.2,
    batteryPercent: 90,
    robotMode: 'AUTO',
    currentLine: 'B',
    checkpoint: 'B-1',
  ),
  TestScenario(
    id: 'warning_air',
    name: 'Skenario 2: Udara Sedang (Waspada)',
    subtitle: 'Debu 82.0 µg/m³ • Status Waspada (Kuning) • Baterai 7.5V (60%)',
    dustLevel: 82.0,
    airStatus: 'WARNING',
    rawStatus: 'Aman',
    batteryVoltage: 7.5,
    batteryPercent: 60,
    robotMode: 'AUTO',
    currentLine: 'B',
    checkpoint: 'B-3',
  ),
  TestScenario(
    id: 'danger_air',
    name: 'Skenario 3: Polusi Tinggi / Bahaya!',
    subtitle: 'Debu 168.0 µg/m³ • Status Bahaya (Merah) • Alarm Aktif',
    dustLevel: 168.0,
    airStatus: 'POOR',
    rawStatus: 'Bahaya',
    batteryVoltage: 7.2,
    batteryPercent: 45,
    robotMode: 'ALERT',
    currentLine: 'B',
    checkpoint: 'B-4',
  ),
  TestScenario(
    id: 'low_battery',
    name: 'Skenario 4: Peringatan Baterai Lemah',
    subtitle: 'Baterai 6.4V (9%) • Muncul Alert Baterai Lemah',
    dustLevel: 22.0,
    airStatus: 'GOOD',
    rawStatus: 'Aman',
    batteryVoltage: 6.4,
    batteryPercent: 9,
    robotMode: 'MANUAL',
    currentLine: 'B',
    checkpoint: 'B-2',
  ),
  TestScenario(
    id: 'mapping_complete',
    name: 'Skenario 5: Peta Rute Lengkap',
    subtitle: 'Simulasi rute inspeksi penuh di MapScreen',
    dustLevel: 26.5,
    airStatus: 'GOOD',
    rawStatus: 'Aman',
    batteryVoltage: 7.8,
    batteryPercent: 73,
    robotMode: 'AUTO',
    currentLine: 'B',
    checkpoint: 'B-2',
    mapData: 'L4500,K,L2000,Ki,L3500,K,L2000,Ki,L3000,K,',
  ),
];
