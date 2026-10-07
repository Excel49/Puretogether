import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/robot_data.dart';

/// Model untuk mencatat riwayat HTTP request/response masuk dan keluar (Live Debugging).
class HttpLogEntry {
  final DateTime timestamp;
  final String direction; // 'IN' atau 'OUT'
  final String source;
  final String payload;
  final bool isError;

  HttpLogEntry({
    required this.timestamp,
    required this.direction,
    required this.source,
    required this.payload,
    this.isError = false,
  });

  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}

/// Service untuk menangani komunikasi jaringan menggunakan HTTP GET polling
class HttpRobotService {
  static const int defaultPort = 80;
  static const String defaultRobotIp = '192.168.4.1';

  Timer? _pollingTimer;
  Timer? _watchdogTimer;

  String _robotIp = defaultRobotIp;
  int _port = defaultPort;
  bool _isConnected = false;
  bool _isRequesting = false; // Mutex untuk cegah tabrakan koneksi

  int _requestsReceived = 0;
  int _requestsSent = 0;
  final List<HttpLogEntry> _logs = [];

  final StreamController<RobotData> _telemetryController =
      StreamController<RobotData>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  final StreamController<String> _rawMessageController =
      StreamController<String>.broadcast();
  final StreamController<List<HttpLogEntry>> _logsController =
      StreamController<List<HttpLogEntry>>.broadcast();

  Stream<RobotData> get telemetryStream => _telemetryController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  Stream<String> get rawMessageStream => _rawMessageController.stream;
  Stream<List<HttpLogEntry>> get logsStream => _logsController.stream;

  bool get isConnected => _isConnected;
  String get robotIp => _robotIp;
  int get port => _port;
  int get requestsReceived => _requestsReceived;
  int get requestsSent => _requestsSent;
  List<HttpLogEntry> get logs => List.unmodifiable(_logs);

  String get _baseUrl => 'http://$_robotIp:$_port';

  /// Memulai polling HTTP ke Robot
  Future<bool> startPolling(
      {String robotIp = defaultRobotIp, int port = defaultPort}) async {
    _robotIp = robotIp;
    _port = port;

    await stopPolling();

    _addLog(
      direction: 'SYS',
      source: _baseUrl,
      payload: 'HTTP Polling Started. Connecting to STM32/ESP-01...',
    );

    debugPrint('[HTTP] Polling started for $_baseUrl');

    // Poll setiap 1.5 detik agar ESP-01 tidak ngos-ngosan
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _fetchTelemetry();
    });

    _resetWatchdog();
    return true;
  }

  Future<void> _fetchTelemetry() async {
    if (_isRequesting) return; // Skip polling jika ada request lain
    _isRequesting = true;
    try {
      // Endpoint root '/' merespons dengan JSON status terkini
      final response = await http.get(Uri.parse('$_baseUrl/')).timeout(
            const Duration(milliseconds: 1500),
          );

      _handleIncomingResponse(response.body);
    } catch (e) {
      debugPrint('[HTTP Polling Error] $e');
      _setConnected(false);
    } finally {
      // JEDA 400ms sebelum ngebolehin request lain jalan
      Future.delayed(const Duration(milliseconds: 400), () {
        _isRequesting = false;
      });
    }
  }

  /// Menangani respons teks dari Robot
  void _handleIncomingResponse(String message) {
    try {
      final trimmed = message.trim();
      _requestsReceived++;
      _rawMessageController.add(trimmed);

      // Add to log occasionally or every time if you want verbose logs
      // _addLog(direction: 'IN', source: _baseUrl, payload: trimmed);

      _setConnected(true);
      _resetWatchdog();

      // Coba parse sebagai JSON:
      // {"status":"Aman", "mode":"Garis", "debu_value":45.2, "battery_voltage":12.0, "map_data":"..."}
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final Map<String, dynamic> json = jsonDecode(trimmed);
        final robotData = RobotData.fromHardwareJson(json);
        _telemetryController.add(robotData);
      } else if (trimmed.startsWith('DATA,')) {
        final robotData = RobotData.fromHardwareCsv(trimmed);
        _telemetryController.add(robotData);
      }
    } catch (e) {
      debugPrint('[HTTP Parse Error] Error decoding JSON: $e');
      _addLog(
          direction: 'ERR',
          source: 'PARSER',
          payload: 'Error parsing: $e',
          isError: true);
    }
  }

  /// Simulasi menerima paket dari STM32 untuk keperluan testing di UI tanpa perangkat fisik
  void simulateIncomingPacket(String sampleJson) {
    try {
      _requestsReceived++;
      _rawMessageController.add(sampleJson);
      _addLog(
          direction: 'IN (SIM)', source: '192.168.4.1:80', payload: sampleJson);

      _setConnected(true);
      _resetWatchdog();

      if (sampleJson.startsWith('{') && sampleJson.endsWith('}')) {
        final Map<String, dynamic> json = jsonDecode(sampleJson);
        final robotData = RobotData.fromHardwareJson(json);
        _telemetryController.add(robotData);
      }
    } catch (e) {
      _addLog(direction: 'ERR', source: 'SIM', payload: '$e', isError: true);
    }
  }

  /// Mengirim command GET request ke robot (misal "/start-map", "/cmd?act=fwd")
  Future<bool> sendCommand(String endpoint) async {
    while (_isRequesting) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isRequesting = true;
    try {
      final url = '$_baseUrl$endpoint';
      _requestsSent++;

      _addLog(direction: 'OUT', source: url, payload: 'GET $endpoint');
      debugPrint('[HTTP Send] Sending GET $endpoint to $_baseUrl');

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 2),
          );

      if (response.statusCode == 200) {
        _handleIncomingResponse(response.body);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      _addLog(
          direction: 'ERR',
          source: 'SEND',
          payload: 'Gagal request "$endpoint": $e',
          isError: true);
      debugPrint('[HTTP Send Error] Failed to send to $endpoint: $e');
      return false;
    } finally {
      // JEDA 400ms sebelum ngebolehin request lain jalan
      Future.delayed(const Duration(milliseconds: 400), () {
        _isRequesting = false;
      });
    }
  }

  /// Mengirim perintah kalibrasi mapping ke STM32
  Future<bool> triggerCalibration() async {
    return sendCommand('/start-map');
  }

  void _addLog({
    required String direction,
    required String source,
    required String payload,
    bool isError = false,
  }) {
    final entry = HttpLogEntry(
      timestamp: DateTime.now(),
      direction: direction,
      source: source,
      payload: payload,
      isError: isError,
    );
    _logs.insert(0, entry);
    if (_logs.length > 100) {
      _logs.removeLast();
    }
    _logsController.add(_logs);
  }

  void clearLogs() {
    _logs.clear();
    _requestsReceived = 0;
    _requestsSent = 0;
    _logsController.add([]);
  }

  void _setConnected(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _connectionStateController.add(_isConnected);
      _addLog(
        direction: 'SYS',
        source: 'WATCHDOG',
        payload: connected
            ? 'Robot ONLINE (HTTP Response Masuk)'
            : 'Robot OFFLINE (Timeout / Gagal Request)',
        isError: !connected,
      );
      debugPrint('[HTTP State] Connection status changed: $_isConnected');
    }
  }

  void _resetWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(milliseconds: 3500), () {
      debugPrint('[HTTP Watchdog] No packets received for 3.5s -> OFFLINE');
      _setConnected(false);
    });
  }

  /// Menutup polling HTTP
  Future<void> stopPolling() async {
    _pollingTimer?.cancel();
    _watchdogTimer?.cancel();
    _setConnected(false);
  }

  void dispose() {
    stopPolling();
    _telemetryController.close();
    _connectionStateController.close();
    _rawMessageController.close();
    _logsController.close();
  }
}
