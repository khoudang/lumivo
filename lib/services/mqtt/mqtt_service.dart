enum MqttConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

abstract interface class MqttService {
  MqttConnectionStatus get status;
  Stream<MqttConnectionStatus> get statusStream;
  Future<bool> connect({
    required String host,
    int port = 8883,
    required String clientId,
    String? username,
    String? password,
  });
  Future<void> disconnect();
  Future<bool> publish(String topic, String payload, {bool retain = false});
  Stream<String> subscribe(String topic);
  Future<void> unsubscribe(String topic);
  Future<void> dispose();
}
