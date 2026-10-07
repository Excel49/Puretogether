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
    required this.lastUpdated,
  });

  factory RobotData.initial() => RobotData(
        airStatus: 'GOOD',
        dustLevel: 12.0,
        batteryPercent: 78,
        batteryVoltage: 12.0,
        robotMode: 'AUTO',
        currentLine: 'B',
        checkpoint: 'B-3',
        connectionStatus: 'OFFLINE',
        mapData: 'L4500,K,L2000,Ki,',
        rawStatus: 'Aman',
        lastUpdated: DateTime.now(),
      );

  /// Konversi voltase baterai (3S 12V Li-ion/LiPo) ke persentase 0..100%
  static int calculateBatteryPercent(double voltage) {
    if (voltage <= 0) return 0;
    if (voltage >= 12.6) return 100;
    if (voltage <= 10.5) return 0;
    final percent = ((voltage - 10.5) / (12.6 - 10.5)) * 100;
    return percent.clamp(0, 100).round();
  }

  /// Parser untuk format JSON Hardware STM32 + ESP-01 via UDP:
  /// {
  ///   "status": "Aman",
  ///   "debu_value": 45.23,
  ///   "battery_voltage": 12.0,
  ///   "map_data": "L4500,K,L2000,Ki,"
  /// }
  factory RobotData.fromHardwareJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString() ?? 'Aman';
    final debuVal = (json['debu_value'] as num?)?.toDouble() ?? 0.0;
    final voltage = (json['battery_voltage'] as num?)?.toDouble() ?? 12.0;
    final mapDataStr = json['map_data']?.toString();

    // Tentukan airStatus berdasarkan status STM32 atau nilai debu
    String airStatus;
    if (rawStatus.toLowerCase() == 'bahaya' || debuVal > 100.0) {
      airStatus = 'POOR';
    } else if (debuVal > 75.0) {
      airStatus = 'WARNING';
    } else {
      airStatus = 'GOOD';
    }

    final mode = (airStatus == 'POOR') ? 'ALERT' : 'AUTO';

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
        parts.length > 3 ? double.tryParse(parts[3].trim()) ?? 12.0 : 12.0;

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
    this.robotPort = 80,
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
