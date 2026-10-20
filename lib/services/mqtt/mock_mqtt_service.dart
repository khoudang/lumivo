import 'dart:async';
import 'dart:math';

import 'mqtt_service.dart';

/// In-memory mock implementation of [MqttService].
///
/// Simulates complete MQTT lifecycle, keepalive pings, auto-reconnection
/// with exponential backoff, in-memory topic routing with MQTT wildcards (+, #),
/// and retained message support.
class MockMqttService implements MqttService {
  MockMqttService({
    this.connectionLatency = const Duration(milliseconds: 100),
    this.keepAliveInterval = const Duration(seconds: 15),
    this.initialReconnectDelay = const Duration(milliseconds: 300),
    this.backoffMultiplier = 2.0,
    this.maxReconnectRetries = 3,
    this.autoReconnect = true,
  });

  final Duration connectionLatency;
  final Duration keepAliveInterval;
  final Duration initialReconnectDelay;
  final double backoffMultiplier;
  final int maxReconnectRetries;
  final bool autoReconnect;

  MqttConnectionStatus _status = MqttConnectionStatus.disconnected;
  final _statusController = StreamController<MqttConnectionStatus>.broadcast();

  final Map<String, StreamController<String>> _topicControllers = {};
  final Map<String, String> _retainedMessages = {};

  Timer? _keepAliveTimer;
  Timer? _reconnectTimer;
  int _pingCount = 0;
  DateTime? _lastPingTime;
  bool _isManualDisconnect = false;
  bool _isDisposed = false;

  String? _lastHost;
  int? _lastPort;
  String? _lastClientId;
  String? _lastUsername;
  String? _lastPassword;

  @override
  MqttConnectionStatus get status => _status;

  @override
  Stream<MqttConnectionStatus> get statusStream => _statusController.stream;

  String? get currentHost => _lastHost;
  int? get currentPort => _lastPort;
  String? get currentClientId => _lastClientId;
  String? get currentUsername => _lastUsername;
  String? get currentPassword => _lastPassword;

  int get pingCount => _pingCount;
  DateTime? get lastPingTime => _lastPingTime;
  Map<String, String> get retainedMessages =>
      Map.unmodifiable(_retainedMessages);

  void _setStatus(MqttConnectionStatus newStatus) {
    if (_isDisposed) return;
    if (_status != newStatus) {
      _status = newStatus;
      if (!_statusController.isClosed) {
        _statusController.add(newStatus);
      }
    }
  }

  @override
  Future<bool> connect({
    required String host,
    int port = 8883,
    required String clientId,
    String? username,
    String? password,
  }) async {
    if (_status == MqttConnectionStatus.connected) {
      return true;
    }

    _isManualDisconnect = false;
    _lastHost = host;
    _lastPort = port;
    _lastClientId = clientId;
    _lastUsername = username;
    _lastPassword = password;

    _setStatus(MqttConnectionStatus.connecting);

    if (connectionLatency > Duration.zero) {
      await Future<void>.delayed(connectionLatency);
    } else {
      await Future<void>.delayed(Duration.zero);
    }

    if (_isManualDisconnect || _isDisposed) {
      return false;
    }

    // Validation for error simulation
    if (host.trim().isEmpty || password == 'fail_connection') {
      _setStatus(MqttConnectionStatus.error);
      return false;
    }

    _setStatus(MqttConnectionStatus.connected);
    _startKeepAliveTimer();
    return true;
  }

  @override
  Future<void> disconnect() async {
    _isManualDisconnect = true;
    _stopKeepAliveTimer();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _setStatus(MqttConnectionStatus.disconnected);
  }

  @override
  Future<bool> publish(
    String topic,
    String payload, {
    bool retain = false,
  }) async {
    if (_status != MqttConnectionStatus.connected) {
      return false;
    }

    if (retain) {
      _retainedMessages[topic] = payload;
    }

    for (final entry in _topicControllers.entries) {
      if (matchesTopicFilter(filter: entry.key, topic: topic)) {
        if (!entry.value.isClosed) {
          entry.value.add(payload);
        }
      }
    }

    return true;
  }

  @override
  Stream<String> subscribe(String topic) {
    final controller = _topicControllers.putIfAbsent(
      topic,
      () => StreamController<String>.broadcast(),
    );

    // Deliver matching retained messages to the new subscriber
    for (final entry in _retainedMessages.entries) {
      if (matchesTopicFilter(filter: topic, topic: entry.key)) {
        scheduleMicrotask(() {
          if (!controller.isClosed) {
            controller.add(entry.value);
          }
        });
      }
    }

    return controller.stream;
  }

  @override
  Future<void> unsubscribe(String topic) async {
    final controller = _topicControllers.remove(topic);
    if (controller != null) {
      await controller.close();
    }
  }

  /// Simulates an unexpected network drop, triggering the auto-reconnect flow.
  Future<void> simulateConnectionDrop(
      {bool shouldSucceedOnRetry = true}) async {
    if (_status != MqttConnectionStatus.connected) return;

    _stopKeepAliveTimer();

    if (!autoReconnect) {
      _setStatus(MqttConnectionStatus.disconnected);
      return;
    }

    _setStatus(MqttConnectionStatus.reconnecting);
    await _performAutoReconnect(shouldSucceed: shouldSucceedOnRetry);
  }

  Future<void> _performAutoReconnect({required bool shouldSucceed}) async {
    for (int attempt = 1; attempt <= maxReconnectRetries; attempt++) {
      final delayMillis = (initialReconnectDelay.inMilliseconds *
              pow(backoffMultiplier, attempt - 1))
          .toInt();

      await Future<void>.delayed(Duration(milliseconds: delayMillis));

      if (_isManualDisconnect || _isDisposed) {
        return;
      }

      // Check if this attempt should succeed
      if (shouldSucceed) {
        _setStatus(MqttConnectionStatus.connected);
        _startKeepAliveTimer();
        return;
      }
    }

    // All retries exhausted
    _setStatus(MqttConnectionStatus.error);
  }

  void _startKeepAliveTimer() {
    _stopKeepAliveTimer();
    _keepAliveTimer = Timer.periodic(keepAliveInterval, (_) {
      if (_status == MqttConnectionStatus.connected) {
        _pingCount++;
        _lastPingTime = DateTime.now();
      }
    });
  }

  void _stopKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  /// Matches MQTT topic filters including single-level (+) and multi-level (#) wildcards.
  static bool matchesTopicFilter({
    required String filter,
    required String topic,
  }) {
    if (filter == topic || filter == '#') return true;

    final filterParts = filter.split('/');
    final topicParts = topic.split('/');

    for (var i = 0; i < filterParts.length; i++) {
      final part = filterParts[i];
      if (part == '#') {
        return true;
      }
      if (i >= topicParts.length) {
        return false;
      }
      if (part != '+' && part != topicParts[i]) {
        return false;
      }
    }

    return filterParts.length == topicParts.length;
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await disconnect();
    for (final controller in _topicControllers.values) {
      await controller.close();
    }
    _topicControllers.clear();
    _retainedMessages.clear();
    await _statusController.close();
  }
}
