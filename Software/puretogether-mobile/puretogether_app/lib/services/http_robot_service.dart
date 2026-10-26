import 'dart:async';
import 'dart:collection';
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

/// Request task dalam antrian sequential
class _QueuedRequest {
  final String endpoint;
  final Completer<bool> completer;
  final DateTime queuedAt;

  _QueuedRequest({
    required this.endpoint,
    required this.completer,
    required this.queuedAt,
  });
}

/// Service untuk menangani komunikasi jaringan menggunakan HTTP GET
/// dengan antrian sequential (Zero Collision) dan telemetri nebeng (Piggybacking).
class HttpRobotService {
  static const int defaultPort = 8888;
  static const String defaultRobotIp = '192.168.4.1';

  Timer? _pollingTimer;
  Timer? _watchdogTimer;

  String _robotIp = defaultRobotIp;
  int _port = defaultPort;
  bool _isConnected = false;

  int _requestsReceived = 0;
  int _requestsSent = 0;
  final List<HttpLogEntry> _logs = [];

  // Antrian sequential: menjamin TIDAK PERNAH ada 2 request bersamaan ke ESP-01
  final Queue<_QueuedRequest> _queue = Queue<_QueuedRequest>();
  bool _isProcessingQueue = false;
  DateTime _lastCommandSentTime = DateTime.fromMillisecondsSinceEpoch(0);

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

  bool _isOneWayManualMode = false; // Default false: langsung polling telemetri saat aplikasi dibuka

  bool get isOneWayManualMode => _isOneWayManualMode;
  set isOneWayManualMode(bool value) {
    if (_isOneWayManualMode != value) {
      _isOneWayManualMode = value;
      debugPrint('[HTTP] One-way manual mode: $value');
      if (value) {
        // Saat mode manual aktif, matikan watchdog dan kunci status pasti ONLINE!
        _watchdogTimer?.cancel();
        _setConnected(true);
      } else {
        _resetWatchdog();
      }
    }
  }

  /// Memulai polling HTTP ke Robot
  Future<bool> startPolling(
      {String robotIp = defaultRobotIp, int port = defaultPort}) async {
    _robotIp = robotIp;
    _port = port;

    await stopPolling();

    _addLog(
      direction: 'SYS',
      source: _baseUrl,
      payload: 'HTTP Service Started on $_baseUrl (Anti-Collision Engine)',
    );

    debugPrint('[HTTP] Polling started for $_baseUrl');

    // Langsung lakukan 1x request awal seketika agar status cepat berubah ONLINE
    _checkAndPollTelemetry();

    // Poll setiap 1.5 detik jika robot sedang menganggur (idle)
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _checkAndPollTelemetry();
    });

    _resetWatchdog();
    return true;
  }

  /// Polling telemetri hanya dilakukan jika tidak sedang aktif mengemudikan robot
  void _checkAndPollTelemetry() {
    // Mode 1-Arah Murni: Matikan total request telemetri saat kemudi manual aktif
    // agar 100% bandwidth ESP-01 dikhususkan untuk kendali tombol tanpa penumpukan data
    if (_isOneWayManualMode) {
      return;
    }

    // Jika ada request perintah dalam 2.5 detik terakhir, abaikan polling sensor
    final timeSinceLastCmd =
        DateTime.now().difference(_lastCommandSentTime).inMilliseconds;
    if (timeSinceLastCmd < 2500) {
      return;
    }

    // Jika antrian sudah terisi atau sedang sibuk, lewati putaran ini
    if (_queue.isNotEmpty || _isProcessingQueue) {
      return;
    }

    // Kirim request telemetri ringan
    sendCommand('/', isTelemetryPoll: true);
  }

  /// Mengirim command GET request ke robot dengan antrian serial non-blocking
  Future<bool> sendCommand(String endpoint,
      {bool isTelemetryPoll = false}) async {
    final completer = Completer<bool>();

    // Jika perintah adalah STOP atau DARURAT, prioritaskan di paling depan antrian
    if (endpoint.contains('act=stop')) {
      // Buang semua antrian perintah gerak lama yang belum sempat terkirim
      _queue.removeWhere((item) => item.endpoint.contains('/cmd?act='));
      _queue.addFirst(_QueuedRequest(
        endpoint: endpoint,
        completer: completer,
        queuedAt: DateTime.now(),
      ));
    } else if (endpoint.contains('/cmd?act=')) {
      // Untuk perintah gerak manual, selalu ganti perintah gerak lama di antrian agar tidak menumpuk delay!
      _queue.removeWhere((item) => item.endpoint.contains('/cmd?act='));
      _queue.addLast(_QueuedRequest(
        endpoint: endpoint,
        completer: completer,
        queuedAt: DateTime.now(),
      ));
    } else {
      if (_queue.length >= 2 && !isTelemetryPoll) {
        final dropped = _queue.removeFirst();
        dropped.completer.complete(false);
      }
      _queue.addLast(_QueuedRequest(
        endpoint: endpoint,
        completer: completer,
        queuedAt: DateTime.now(),
      ));
    }

    if (!isTelemetryPoll) {
      _lastCommandSentTime = DateTime.now();
    }

    _processQueue();
    return completer.future;
  }

  /// Memproses item antrian satu per satu (Mencegah collision di ESP-01)
  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_queue.isNotEmpty) {
      final req = _queue.removeFirst();
      final url = '$_baseUrl${req.endpoint}';
      final isMotorCmd = req.endpoint.contains('/cmd?act=');

      try {
        _requestsSent++;
        _addLog(direction: 'OUT', source: url, payload: 'GET ${req.endpoint}');
        debugPrint('[HTTP Out] GET ${req.endpoint}');

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Connection': 'close',
          },
        ).timeout(
          // Untuk perintah motor, timeout super singkat (250ms) karena STM32 langsung menutup socket (Zero-Delay)
          Duration(milliseconds: isMotorCmd ? 250 : 2000),
        );

        if (response.statusCode == 200) {
          // Jika sedang di mode Manual 1-Arah, abaikan data balasan sama sekali!
          if (!_isOneWayManualMode && !isMotorCmd) {
            _handleIncomingResponse(response.body);
          }
          if (!req.completer.isCompleted) {
            req.completer.complete(true);
          }
        } else {
          if (!req.completer.isCompleted) {
            req.completer.complete(false);
          }
        }
      } catch (e) {
        // Saat mode manual (atau perintah motor), JANGAN PERNAH ubah status menjadi OFFLINE!
        // Begitu di mode manual, status dikunci tetap ONLINE tanpa pengecekan konektivitas.
        if (_isOneWayManualMode || isMotorCmd) {
          _setConnected(true);
          if (!req.completer.isCompleted) {
            req.completer.complete(true);
          }
        } else {
          _addLog(
            direction: 'ERR',
            source: 'SEND',
            payload: 'Gagal GET "${req.endpoint}": $e',
            isError: true,
          );
          debugPrint('[HTTP Exception] ${req.endpoint}: $e');
          _setConnected(false); // Hanya ubah OFFLINE jika di luar mode manual
          if (!req.completer.isCompleted) {
            req.completer.complete(false);
          }
        }
      }

      // Jeda nafas singkat 10ms antar paket
      await Future.delayed(const Duration(milliseconds: 10));
    }

    _isProcessingQueue = false;
  }

  /// Menangani respons teks dari Robot
  void _handleIncomingResponse(String message) {
    try {
      final trimmed = message.trim();
      _requestsReceived++;
      _rawMessageController.add(trimmed);

      _setConnected(true);
      _resetWatchdog();

      // Coba parse sebagai JSON:
      // {"status":"Aman","mode":"Remote Manual","debu_value":45.2,"battery_voltage":12.0,...}
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
        isError: true,
      );
    }
  }

  /// Simulasi menerima paket dari STM32 untuk keperluan testing di UI tanpa perangkat fisik
  void simulateIncomingPacket(String sampleJson) {
    try {
      _requestsReceived++;
      _rawMessageController.add(sampleJson);
      _addLog(
        direction: 'IN (SIM)',
        source: '192.168.4.1:$defaultPort',
        payload: sampleJson,
      );

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
    // Di mode 1-arah murni, polling background sengaja dihentikan demi keutuhan bandwidth kemudi.
    // Robot hanya dianggap OFFLINE jika request perintah tombol gagal / timeout.
    if (_isOneWayManualMode) {
      return;
    }
    _watchdogTimer = Timer(const Duration(milliseconds: 9000), () {
      debugPrint('[HTTP Watchdog] No packets received for 9.0s -> OFFLINE');
      _setConnected(false);
    });
  }

  /// Menutup polling HTTP
  Future<void> stopPolling() async {
    _pollingTimer?.cancel();
    _watchdogTimer?.cancel();
    _queue.clear();
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
