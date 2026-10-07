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

  RobotProvider() {
    _initHttpListener();
  }

  // ── Getters ───────────────────────────────────────────────────
  RobotData get data => _data;
  RobotSettings get settings => _settings;
  List<AlertEntry> get alerts => _alerts;
  bool get isMockMode => _isMockMode;
  bool get isConnecting => _isConnecting;
  bool get isCalibrating => _isCalibrating;
  String? get lastHttpMessage => _lastHttpMessage;
  bool get isHttpConnected => _httpService.isConnected;
  
  bool get isRecordingManual => _isRecordingManual;
  String get manualMapBuffer => _manualMapBuffer;

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
      _data = newData;
      _isMockMode = false;
      _isConnecting = false;

      // Cek trigger alert otomatis jika debu tinggi
      if (newData.airStatus == 'POOR') {
        _checkAndAddHighDustAlert(newData.dustLevel);
      }
      notifyListeners();
    });

    // Dengarkan status koneksi
    _connectionSub = _httpService.connectionStateStream.listen((connected) {
      _data = _data.copyWith(
        connectionStatus: connected ? 'ONLINE' : 'OFFLINE',
      );
      if (!connected && _isCalibrating) {
        _isCalibrating = false;
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

  // ── Kalibrasi Jalur Peta Otomatis (Line Follower) ───────────────
  Future<bool> startCalibration() async {
    _isCalibrating = true;
    notifyListeners();

    debugPrint('[RobotProvider] Sending /start-map to http://${_settings.robotIp}:${_settings.robotPort}');
    final success = await _httpService.triggerCalibration();

    if (!success && _isMockMode) {
      // Mock simulation
      Timer(const Duration(seconds: 4), () {
        _isCalibrating = false;
        _data = _data.copyWith(
          mapData: 'L4500,K,L2000,Ki,L3000,K,L2000,Ki,',
        );
        addAlert(
          AlertEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: 'PATROL_FINISHED',
            timestamp: DateTime.now(),
            message: 'Kalibrasi jalur selesai. Peta berhasil diperbarui!',
          ),
        );
        notifyListeners();
      });
    }

    return success;
  }

  void stopCalibration() {
    _isCalibrating = false;
    notifyListeners();
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
          message: 'Pemetaan manual dimulai. Gunakan D-Pad untuk melaju.',
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
          message: 'Pemetaan manual selesai dan tersimpan!',
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
        if (_startStraightTime == null) {
          _startStraightTime = DateTime.now();
        }
        break;
      case 'MOVE_LEFT':
        _processManualStraightSegment();
        _manualMapBuffer += 'Ki,'; // Kiri
        break;
      case 'MOVE_RIGHT':
        _processManualStraightSegment();
        _manualMapBuffer += 'K,';  // Kanan
        break;
      case 'STOP':
      case 'MOVE_BACKWARD':
        _processManualStraightSegment();
        break;
    }
  }

  // ── Commands (Kongtrol Motor, Mode, Emote) ──────────────────────
  Future<void> sendCommand(String command) async {
    debugPrint('[RobotProvider] Executing command: $command');

    // Catat ke memori peta manual jika sedang aktif
    if (['MOVE_FORWARD', 'MOVE_BACKWARD', 'MOVE_LEFT', 'MOVE_RIGHT', 'STOP'].contains(command)) {
      _recordManualMovement(command);
    }

    String endpoint = '';
    // Konversi command level atas ke HTTP Endpoint
    switch (command) {
      case 'SET_AUTO':
        endpoint = '/mode?val=auto';
        _data = _data.copyWith(robotMode: 'AUTO');
        break;
      case 'SET_MANUAL':
        endpoint = '/mode?val=manual';
        _data = _data.copyWith(robotMode: 'MANUAL');
        break;
      case 'START_PATROL':
        endpoint = '/mode?val=auto';
        _data = _data.copyWith(robotMode: 'AUTO', currentLine: 'B', checkpoint: 'B-1');
        break;
      case 'PAUSE':
        endpoint = '/cmd?act=stop';
        _data = _data.copyWith(robotMode: 'MANUAL');
        break;
      case 'STOP':
      case 'EMERGENCY_STOP':
        endpoint = '/cmd?act=stop';
        _data = _data.copyWith(robotMode: 'MANUAL');
        break;
      case 'RETURN_HOME':
        endpoint = '/mode?val=auto';
        _data = _data.copyWith(currentLine: 'B', checkpoint: 'B-1');
        break;
      case 'MOVE_FORWARD':
        endpoint = '/cmd?act=fwd';
        break;
      case 'MOVE_BACKWARD':
        endpoint = '/cmd?act=rev';
        break;
      case 'MOVE_LEFT':
        endpoint = '/cmd?act=left';
        break;
      case 'MOVE_RIGHT':
        endpoint = '/cmd?act=right';
        break;
      case 'EMOTE_HAPPY':
        endpoint = '/emote?type=happy';
        break;
      case 'EMOTE_ANGRY':
        endpoint = '/emote?type=angry';
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
    {'air_status': 'GOOD', 'dust_level': 12.0, 'robot_mode': 'AUTO', 'current_line': 'B', 'checkpoint': 'B-1', 'voltage': 12.1},
    {'air_status': 'GOOD', 'dust_level': 14.5, 'robot_mode': 'AUTO', 'current_line': 'B', 'checkpoint': 'B-2', 'voltage': 12.0},
    {'air_status': 'POOR', 'dust_level': 120.0, 'robot_mode': 'ALERT', 'current_line': 'B', 'checkpoint': 'B-4', 'voltage': 11.8},
  ];

  static List<AlertEntry> _initialAlerts() => [
        AlertEntry(
          id: '1',
          type: 'AIR_NORMAL',
          timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
          message: 'Air quality back to normal (18 µg/m³)',
          dustLevel: 18.0,
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
        message: 'Dust sensor reading above threshold (${dustLevel.toStringAsFixed(1)} µg/m³)',
        dustLevel: dustLevel,
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
    _mockTimer?.cancel();
    _telemetrySub?.cancel();
    _connectionSub?.cancel();
    _rawMessageSub?.cancel();
    _httpService.dispose();
    super.dispose();
  }
}
