import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/robot_data.dart';
import '../services/http_robot_service.dart';

/// Provider utama yang mengelola state robot, HTTP Polling,
/// kalibrasi pemetaan, dan simulasi mock fallback.
class RobotProvider extends ChangeNotifier {
  RobotData _data = RobotData.initial();
  RobotSettings _settings = const RobotSettings();
  List<AlertEntry> _alerts = _initialAlerts();
  bool _isMockMode = false;
  bool _isConnecting = false;
  bool _isCalibrating = false;
  String? _lastHttpMessage;
  String? _activeScenarioId;

  // Manual Mapping State
  bool _isRecordingManual = false;
  String _manualMapBuffer = '';
  DateTime? _startStraightTime;

  final HttpRobotService _httpService = HttpRobotService();
  StreamSubscription<RobotData>? _telemetrySub;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<String>? _rawMessageSub;

  Timer? _mockTimer;
  int _mockIndex = 0;
  final Random _rng = Random();
  Timer? _idleTransitionTimer;
  Timer? _stopDebounceTimer;

  RobotProvider() {
    _httpService.isOneWayManualMode = false; // Default IDLE: telemetri mengalir ke Flutter
    _initHttpListener();
  }

  // ── Getters ───────────────────────────────────────────────────
  RobotData get data => _data;
  bool get isSmokeDanger => _data.airStatus == 'POOR' || _data.dustLevel > 100.0;
  RobotSettings get settings => _settings;
  List<AlertEntry> get alerts => _alerts;
  bool get isMockMode => _isMockMode;
  bool get isConnecting => _isConnecting;
  bool get isCalibrating => _isCalibrating;
  String? get lastHttpMessage => _lastHttpMessage;
  bool get isHttpConnected => _httpService.isConnected;
  String? get activeScenarioId => _activeScenarioId;
  bool get isScenarioActive => _activeScenarioId != null;
  bool get isOneWayManualMode => _httpService.isOneWayManualMode;
  
  bool get isRecordingManual => _isRecordingManual;
  String get manualMapBuffer => _manualMapBuffer;

  /// Daftar langkah rute yang sedang direkam dalam format user-friendly
  List<String> get manualMapSteps {
    final source = _isRecordingManual
        ? _manualMapBuffer
        : (_manualMapBuffer.isNotEmpty ? _manualMapBuffer : (_data.mapData ?? ''));
    if (source.isEmpty) return [];
    return source.split(',').where((s) => s.isNotEmpty).map((item) {
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
    }).toList();
  }

  void clearManualMapBuffer() {
    _manualMapBuffer = '';
    _startStraightTime = null;
    _data = _data.copyWith(mapData: '');
    _httpService.sendCommand('/save-map?data=');
    notifyListeners();
  }

  /// Request data sensor 1x (on-demand) tanpa memulai polling terus-menerus
  Future<void> fetchTelemetryOnce() async {
    await _httpService.sendCommand('/', isTelemetryPoll: true);
  }

  // ── HTTP Debugging & Live Logs ─────────────────────────────────
  List<HttpLogEntry> get httpLogs => _httpService.logs;
  Stream<List<HttpLogEntry>> get httpLogsStream => _httpService.logsStream;
  int get httpRequestsReceived => _httpService.requestsReceived;
  int get httpRequestsSent => _httpService.requestsSent;
  void clearHttpLogs() {
    _httpService.clearLogs();
    notifyListeners();
  }
  void simulateHttpPacket(String sampleJson) {
    _httpService.simulateIncomingPacket(sampleJson);
  }

  // ── Inisialisasi HTTP Polling ───────────────────────────────────
  Future<void> _initHttpListener() async {
    _telemetrySub?.cancel();
    _connectionSub?.cancel();
    _rawMessageSub?.cancel();

    // Dengarkan data telemetri real-time dari STM32
    _telemetrySub = _httpService.telemetryStream.listen((newData) {
      _mockTimer?.cancel();

      // Jika skenario test sedang aktif, pertahankan nilai simulasi debu/status
      if (_activeScenarioId != null) {
        _data = newData.copyWith(
          airStatus: _data.airStatus,
          dustLevel: _data.dustLevel,
          rawStatus: _data.rawStatus,
          batteryVoltage: _data.batteryVoltage,
          batteryPercent: _data.batteryPercent,
          robotMode: _data.robotMode,
          mapData: _data.mapData,
        );
      } else {
        // Pertahankan status MANUAL atau IDLE jika sedang tidak ada bahaya POOR
        String preservedMode = newData.robotMode;
        if ((_data.robotMode == 'MANUAL' || _data.robotMode == 'IDLE') &&
            newData.airStatus != 'POOR') {
          preservedMode = _data.robotMode;
        }
        _data = newData.copyWith(robotMode: preservedMode);
      }

      _isMockMode = false;
      _isConnecting = false;
      _isCalibrating = false;

      // Cek trigger alert otomatis jika debu tinggi / asap
      final wasPoor = _data.airStatus == 'POOR';
      if (newData.airStatus == 'POOR') {
        _checkAndAddHighDustAlert(newData.dustLevel);
        // Bahaya asap: alihkan aliran data dari robot ke Flutter dan batalkan mode kemudi
        _httpService.isOneWayManualMode = false;
        _idleTransitionTimer?.cancel();
      } else if (wasPoor && newData.airStatus != 'POOR') {
        addAlert(
          AlertEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: 'AIR_NORMAL',
            timestamp: DateTime.now(),
            message: 'Kualitas udara kembali aman (${newData.dustLevel.toStringAsFixed(1)} µg/m³)',
            dustLevel: newData.dustLevel,
          ),
        );
      }

      // Cek trigger alert otomatis jika baterai lemah (<= 20%)
      if (newData.batteryPercent <= 20) {
        _checkAndAddLowBatteryAlert(newData.batteryPercent, newData.batteryVoltage);
      }

      notifyListeners();
    });

    // Dengarkan status koneksi
    _connectionSub = _httpService.connectionStateStream.listen((connected) {
      // Jika sedang di mode MANUAL, abaikan status putus/offline — kunci tetap ONLINE!
      if (_data.robotMode == 'MANUAL' && !connected) {
        return;
      }
      final wasOnline = _data.connectionStatus == 'ONLINE';
      _data = _data.copyWith(
        connectionStatus: connected ? 'ONLINE' : 'OFFLINE',
      );
      if (!connected && wasOnline) {
        addAlert(
          AlertEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: 'ROBOT_OFFLINE',
            timestamp: DateTime.now(),
            message: 'Koneksi dengan robot terputus (Offline)',
          ),
        );
      } else if (connected && !wasOnline) {
        addAlert(
          AlertEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: 'ROBOT_ONLINE',
            timestamp: DateTime.now(),
            message: 'Robot berhasil terhubung (Online via Hotspot PureTogether)',
          ),
        );
      }
      notifyListeners();
    });

    // Dengarkan pesan raw string untuk debugging / feedback
    _rawMessageSub = _httpService.rawMessageStream.listen((msg) {
      _lastHttpMessage = msg;
      notifyListeners();
    });

    // Mulai polling ke HTTP Server
    await _httpService.startPolling(
      robotIp: _settings.robotIp,
      port: _settings.robotPort,
    );
  }

  // ── Manual Mapping Logic (App-Side Tracking) ───────────────────
  void toggleManualRecording() {
    _isRecordingManual = !_isRecordingManual;
    if (_isRecordingManual) {
      _manualMapBuffer = '';
      _startStraightTime = null;
      addAlert(
        AlertEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'MANUAL_MAP',
          timestamp: DateTime.now(),
          message: 'Pemetaan manual dimulai. Gunakan D-Pad untuk melaju & belok lurus.',
        ),
      );
    } else {
      _processManualStraightSegment(); // End any ongoing straight segment
      // Send the completed buffer to robot to replace trackMap
      if (_manualMapBuffer.isNotEmpty) {
        debugPrint('[ManualMap] Saving: $_manualMapBuffer');
        _httpService.sendCommand('/save-map?data=${Uri.encodeComponent(_manualMapBuffer)}');
        _data = _data.copyWith(mapData: _manualMapBuffer);
      }
      addAlert(
        AlertEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'MANUAL_MAP',
          timestamp: DateTime.now(),
          message: 'Pemetaan manual selesai dan tersimpan ke robot!',
        ),
      );
    }
    notifyListeners();
  }

  void _processManualStraightSegment() {
    if (_startStraightTime != null) {
      final diff = DateTime.now().difference(_startStraightTime!).inMilliseconds;
      if (diff > 100) {
        _manualMapBuffer += 'L$diff,';
      }
      _startStraightTime = null;
    }
  }

  void _recordManualMovement(String command) {
    if (!_isRecordingManual) return;

    switch (command) {
      case 'MOVE_FORWARD':
        _startStraightTime ??= DateTime.now();
        break;
      case 'MOVE_LEFT':
      case 'MOVE_FORWARD_LEFT':
        // Belok lurus kiri tanpa berhenti dahulu: tutup segmen lurus sebelumnya,
        // catat belok kiri, dan langsung lanjutkan perhitungan jalan lurus
        _processManualStraightSegment();
        _manualMapBuffer += 'Ki,';
        _startStraightTime = DateTime.now();
        break;
      case 'MOVE_RIGHT':
      case 'MOVE_FORWARD_RIGHT':
        // Belok lurus kanan tanpa berhenti dahulu: tutup segmen lurus sebelumnya,
        // catat belok kanan, dan langsung lanjutkan perhitungan jalan lurus
        _processManualStraightSegment();
        _manualMapBuffer += 'K,';
        _startStraightTime = DateTime.now();
        break;
      case 'STOP':
      case 'MOVE_BACKWARD':
        _processManualStraightSegment();
        break;
    }
    // Perbarui preview peta secara real-time selama merekam
    if (_manualMapBuffer.isNotEmpty) {
      _data = _data.copyWith(mapData: _manualMapBuffer);
    }
  }

  void _startIdleTransitionTimer() {
    _idleTransitionTimer?.cancel();
    _idleTransitionTimer = Timer(const Duration(seconds: 3), () {
      if (_data.robotMode == 'MANUAL') {
        debugPrint('[RobotProvider] Inaktivitas 3 detik -> Beralih otomatis ke IDLE mode');
        _data = _data.copyWith(robotMode: 'IDLE');
        _httpService.isOneWayManualMode = false; // Buka aliran data dari robot ke Flutter
        notifyListeners();
      }
    });
  }

  static const _moveCommands = [
    'MOVE_FORWARD',
    'MOVE_BACKWARD',
    'MOVE_LEFT',
    'MOVE_RIGHT',
    'MOVE_FORWARD_LEFT',
    'MOVE_FORWARD_RIGHT',
  ];

  // ── Commands (Kontrol Motor, Mode, Emote) ──────────────────────
  Future<void> sendCommand(String command) async {
    debugPrint('[RobotProvider] Executing command: $command');

    // Jika tombol arah ditekan, batalkan debounce STOP agar mobil langsung belok/lurus tanpa berhenti dahulu
    if (_moveCommands.contains(command)) {
      _stopDebounceTimer?.cancel();
      _stopDebounceTimer = null;

      // Jika robot mendeteksi asap / bahaya udara, tolak perintah gerak manual
      if (isSmokeDanger) {
        debugPrint('[RobotProvider] Gerak ditolak! Bahaya asap terdeteksi.');
        addAlert(
          AlertEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: 'DUST_HIGH',
            timestamp: DateTime.now(),
            message: 'Mobil dilarang bergerak! Asap terdeteksi (${_data.dustLevel.toStringAsFixed(1)} µg/m³)',
            dustLevel: _data.dustLevel,
          ),
        );
        notifyListeners();
        return;
      }
    }

    // Jika perintah STOP (saat melepas tombol D-Pad), langsung kirim STOP seketika tanpa delay!
    if (command == 'STOP') {
      _stopDebounceTimer?.cancel();
      _recordManualMovement('STOP');
      if (_data.robotMode == 'MANUAL') {
        _data = _data.copyWith(connectionStatus: 'ONLINE');
        _startIdleTransitionTimer();
      } else if (_data.robotMode == 'AUTO') {
        _data = _data.copyWith(robotMode: 'IDLE');
        _httpService.isOneWayManualMode = false;
      }
      await _httpService.sendCommand('/cmd?act=stop');
      notifyListeners();
      return;
    }

    // Catat ke memori peta manual jika sedang aktif
    if (_moveCommands.contains(command) || command == 'EMERGENCY_STOP') {
      _recordManualMovement(command == 'EMERGENCY_STOP' ? 'STOP' : command);
    }

    String endpoint = '';
    // Konversi command level atas ke HTTP Endpoint
    switch (command) {
      case 'SET_AUTO':
        _stopDebounceTimer?.cancel();
        _idleTransitionTimer?.cancel();
        endpoint = '/mode?val=auto';
        _data = _data.copyWith(robotMode: 'AUTO');
        _httpService.isOneWayManualMode = false; // Aktifkan polling di mode Auto
        break;
      case 'SET_IDLE':
        _stopDebounceTimer?.cancel();
        _idleTransitionTimer?.cancel();
        endpoint = '/cmd?act=stop';
        _data = _data.copyWith(robotMode: 'IDLE');
        _httpService.isOneWayManualMode = false; // Buka aliran data dari robot ke Flutter
        break;
      case 'SET_MANUAL':
        _stopDebounceTimer?.cancel();
        endpoint = '/mode?val=manual';
        // Begitu masuk mode Manual, kunci status koneksi pasti ONLINE!
        _data = _data.copyWith(robotMode: 'MANUAL', connectionStatus: 'ONLINE');
        _httpService.isOneWayManualMode = true; // 1-arah murni di mode Manual
        _startIdleTransitionTimer(); // Otomatis ke IDLE jika diam 3 detik
        break;
      case 'START_PATROL':
        _stopDebounceTimer?.cancel();
        _idleTransitionTimer?.cancel();
        endpoint = '/mode?val=auto';
        _data = _data.copyWith(robotMode: 'AUTO', currentLine: 'B', checkpoint: 'B-1');
        _httpService.isOneWayManualMode = false;
        break;
      case 'PAUSE':
        _stopDebounceTimer?.cancel();
        _idleTransitionTimer?.cancel();
        endpoint = '/cmd?act=stop';
        _data = _data.copyWith(robotMode: 'IDLE');
        _httpService.isOneWayManualMode = false;
        break;
      case 'EMERGENCY_STOP':
        _stopDebounceTimer?.cancel();
        endpoint = '/cmd?act=stop';
        if (_data.robotMode == 'MANUAL') {
          _data = _data.copyWith(connectionStatus: 'ONLINE');
          _startIdleTransitionTimer();
        } else if (_data.robotMode == 'AUTO') {
          _data = _data.copyWith(robotMode: 'IDLE');
          _httpService.isOneWayManualMode = false;
        }
        break;
      case 'RETURN_HOME':
        _stopDebounceTimer?.cancel();
        _idleTransitionTimer?.cancel();
        endpoint = '/mode?val=auto';
        _data = _data.copyWith(currentLine: 'B', checkpoint: 'B-1');
        _httpService.isOneWayManualMode = false;
        break;
      case 'MOVE_FORWARD':
        _idleTransitionTimer?.cancel();
        _data = _data.copyWith(robotMode: 'MANUAL', connectionStatus: 'ONLINE');
        _httpService.isOneWayManualMode = true;
        endpoint = '/cmd?act=fwd';
        break;
      case 'MOVE_BACKWARD':
        _idleTransitionTimer?.cancel();
        _data = _data.copyWith(robotMode: 'MANUAL', connectionStatus: 'ONLINE');
        _httpService.isOneWayManualMode = true;
        endpoint = '/cmd?act=rev';
        break;
      case 'MOVE_LEFT':
        _idleTransitionTimer?.cancel();
        _data = _data.copyWith(robotMode: 'MANUAL', connectionStatus: 'ONLINE');
        _httpService.isOneWayManualMode = true;
        endpoint = '/cmd?act=left';
        break;
      case 'MOVE_RIGHT':
        _idleTransitionTimer?.cancel();
        _data = _data.copyWith(robotMode: 'MANUAL', connectionStatus: 'ONLINE');
        _httpService.isOneWayManualMode = true;
        endpoint = '/cmd?act=right';
        break;
      case 'MOVE_FORWARD_LEFT':
        _idleTransitionTimer?.cancel();
        _data = _data.copyWith(robotMode: 'MANUAL', connectionStatus: 'ONLINE');
        _httpService.isOneWayManualMode = true;
        endpoint = '/cmd?act=sleft';
        break;
      case 'MOVE_FORWARD_RIGHT':
        _idleTransitionTimer?.cancel();
        _data = _data.copyWith(robotMode: 'MANUAL', connectionStatus: 'ONLINE');
        _httpService.isOneWayManualMode = true;
        endpoint = '/cmd?act=sright';
        break;
      case 'EMOTE_HAPPY':
        endpoint = '/emote?type=happy';
        break;
      case 'EMOTE_ANGRY':
        endpoint = '/emote?type=angry';
        break;
      case 'EMOTE_BIRTHDAY':
        endpoint = '/emote?type=birthday';
        break;
    }

    // 1. Tembak perintah HTTP GET ke Robot
    if (endpoint.isNotEmpty) {
      await _httpService.sendCommand(endpoint);
    }
    
    // 2. Update state lokal
    notifyListeners();
  }

  // ── Mock scenarios (Fallback testing jika hardware belum dinyalakan) ──
  static const _scenarios = [
    {'air_status': 'GOOD', 'dust_level': 12.0, 'robot_mode': 'AUTO', 'current_line': 'B', 'checkpoint': 'B-1', 'voltage': 7.5},
    {'air_status': 'GOOD', 'dust_level': 14.5, 'robot_mode': 'AUTO', 'current_line': 'B', 'checkpoint': 'B-2', 'voltage': 7.4},
    {'air_status': 'POOR', 'dust_level': 120.0, 'robot_mode': 'ALERT', 'current_line': 'B', 'checkpoint': 'B-4', 'voltage': 7.2},
  ];

  static List<AlertEntry> _initialAlerts() => [
        AlertEntry(
          id: 'init_1',
          type: 'AIR_NORMAL',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          message: 'Sistem siap. Kualitas udara awal terpantau normal.',
          dustLevel: 12.0,
        ),
      ];

  void _checkAndAddHighDustAlert(double dustLevel) {
    if (_alerts.isNotEmpty &&
        _alerts.first.type == 'DUST_HIGH' &&
        DateTime.now().difference(_alerts.first.timestamp).inSeconds < 60) {
      return; 
    }
    addAlert(
      AlertEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'DUST_HIGH',
        timestamp: DateTime.now(),
        message: 'Kadar debu tinggi (${dustLevel.toStringAsFixed(1)} µg/m³)! Melebihi ambang batas.',
        dustLevel: dustLevel,
      ),
    );
  }

  void _checkAndAddLowBatteryAlert(int percent, double voltage) {
    if (_alerts.isNotEmpty &&
        _alerts.first.type == 'BATTERY_LOW' &&
        DateTime.now().difference(_alerts.first.timestamp).inSeconds < 120) {
      return; 
    }
    addAlert(
      AlertEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'BATTERY_LOW',
        timestamp: DateTime.now(),
        message: 'Baterai robot lemah ($percent% - ${voltage.toStringAsFixed(1)}V). Segera isi daya!',
        batteryPercent: percent,
      ),
    );
  }

  void startMockMode() {
    _isMockMode = true;
    _isConnecting = false;
    _mockTimer?.cancel();
    _mockIndex = 0;

    _mockTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final s = _scenarios[_mockIndex % _scenarios.length];
      _mockIndex++;
      final volt = s['voltage'] as double;
      final battery = RobotData.calculateBatteryPercent(volt);

      _data = _data.copyWith(
        airStatus: s['air_status'] as String,
        dustLevel: (s['dust_level'] as num).toDouble() + _rng.nextDouble() * 2,
        robotMode: s['robot_mode'] as String,
        currentLine: s['current_line'] as String,
        checkpoint: s['checkpoint'] as String,
        batteryPercent: battery,
        batteryVoltage: volt,
        connectionStatus: 'ONLINE',
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
    });

    _data = _data.copyWith(connectionStatus: 'ONLINE');
    notifyListeners();
  }

  void startConnecting() {
    _isConnecting = true;
    notifyListeners();
  }

  void stopMock() {
    _mockTimer?.cancel();
    _mockTimer = null;
    _isMockMode = false;
    _data = _data.copyWith(connectionStatus: _httpService.isConnected ? 'ONLINE' : 'OFFLINE');
    notifyListeners();
  }

  // ── Testing & Simulasi Sensor ───────────────────────────────
  void applyTestScenario(TestScenario scenario) {
    _activeScenarioId = scenario.id;
    _data = _data.copyWith(
      dustLevel: scenario.dustLevel,
      airStatus: scenario.airStatus,
      rawStatus: scenario.rawStatus,
      batteryPercent: scenario.batteryPercent,
      batteryVoltage: scenario.batteryVoltage,
      robotMode: scenario.robotMode,
      mapData: scenario.mapData ?? _data.mapData,
      lastUpdated: DateTime.now(),
    );

    // Kirim juga ke STM32 jika terhubung agar firmware sinkron
    if (_httpService.isConnected) {
      _httpService.sendCommand('/dummy?dust=${scenario.dustLevel.toInt()}');
    }

    if (scenario.airStatus == 'POOR') {
      _checkAndAddHighDustAlert(scenario.dustLevel);
    }
    notifyListeners();
  }

  void clearTestScenario() {
    _activeScenarioId = null;
    if (_httpService.isConnected) {
      _httpService.sendCommand('/dummy?dust=-1'); // reset ke hardware
    }
    notifyListeners();
  }

  // ── Settings ─────────────────────────────────────────────────
  Future<void> updateSettings(RobotSettings s) async {
    final needReconnect = s.robotIp != _settings.robotIp || s.robotPort != _settings.robotPort;
    _settings = s;
    notifyListeners();

    if (needReconnect) {
      await _httpService.startPolling(
        robotIp: _settings.robotIp,
        port: _settings.robotPort,
      );
    }
  }

  // ── Alerts ───────────────────────────────────────────────────
  void addAlert(AlertEntry alert) {
    _alerts = [alert, ..._alerts].take(50).toList();
    notifyListeners();
  }

  void clearAlerts() {
    _alerts = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _stopDebounceTimer?.cancel();
    _idleTransitionTimer?.cancel();
    _mockTimer?.cancel();
    _telemetrySub?.cancel();
    _connectionSub?.cancel();
    _rawMessageSub?.cancel();
    _httpService.dispose();
    super.dispose();
  }
}
