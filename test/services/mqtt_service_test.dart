import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/services/mqtt/mock_mqtt_service.dart';
import 'package:lumivo/services/mqtt/mqtt_service.dart';

void main() {
  group('MockMqttService', () {
    late MockMqttService service;

    setUp(() {
      service = MockMqttService(
        connectionLatency: Duration.zero,
        keepAliveInterval: const Duration(milliseconds: 30),
        initialReconnectDelay: const Duration(milliseconds: 20),
        maxReconnectRetries: 2,
      );
    });

    tearDown(() async {
      await service.dispose();
    });

    test('lifecycle: disconnected -> connecting -> connected', () async {
      expect(service.status, equals(MqttConnectionStatus.disconnected));

      final statuses = <MqttConnectionStatus>[];
      final sub = service.statusStream.listen(statuses.add);

      final success = await service.connect(
        host: 'broker.lumivo.internal',
        clientId: 'client-test-1',
      );

      expect(success, isTrue);
      expect(service.status, equals(MqttConnectionStatus.connected));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
          statuses,
          containsAllInOrder([
            MqttConnectionStatus.connecting,
            MqttConnectionStatus.connected,
          ]));

      await service.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.status, equals(MqttConnectionStatus.disconnected));
      expect(statuses.last, equals(MqttConnectionStatus.disconnected));

      await sub.cancel();
    });

    test('fails on invalid host or fail_connection password', () async {
      final success = await service.connect(
        host: '',
        clientId: 'test-client',
      );

      expect(success, isFalse);
      expect(service.status, equals(MqttConnectionStatus.error));
    });

    test('publishes and receives messages via in-memory routing', () async {
      await service.connect(
        host: 'broker.lumivo.internal',
        clientId: 'client-test-2',
      );

      final messages = <String>[];
      final stream = service.subscribe('lumivo/light-1/status');
      final sub = stream.listen(messages.add);

      await service.publish('lumivo/light-1/status', '{"state": "on"}');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(messages, equals(['{"state": "on"}']));

      await service.unsubscribe('lumivo/light-1/status');
      await service.publish('lumivo/light-1/status', '{"state": "off"}');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Should not have received the second message after unsubscribe
      expect(messages.length, equals(1));
      await sub.cancel();
    });

    test('supports MQTT wildcard routing (+ and #)', () async {
      await service.connect(
        host: 'broker.lumivo.internal',
        clientId: 'client-test-3',
      );

      final plusMessages = <String>[];
      final hashMessages = <String>[];

      final plusSub =
          service.subscribe('lumivo/+/status').listen(plusMessages.add);
      final hashSub = service.subscribe('lumivo/#').listen(hashMessages.add);

      await service.publish('lumivo/bulb-a19/status', 'bulb-status');
      await service.publish('lumivo/plug-1/set', 'plug-set');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(plusMessages, equals(['bulb-status']));
      expect(hashMessages, equals(['bulb-status', 'plug-set']));

      await plusSub.cancel();
      await hashSub.cancel();
    });

    test('delivers retained messages to new subscribers', () async {
      await service.connect(
        host: 'broker.lumivo.internal',
        clientId: 'client-test-4',
      );

      await service.publish(
        'lumivo/sensor-1/temperature',
        '24.5',
        retain: true,
      );

      final received =
          await service.subscribe('lumivo/sensor-1/temperature').first;
      expect(received, equals('24.5'));
    });

    test('simulates auto-reconnect on connection drop', () async {
      await service.connect(
        host: 'broker.lumivo.internal',
        clientId: 'client-test-5',
      );

      final statuses = <MqttConnectionStatus>[];
      final sub = service.statusStream.listen(statuses.add);

      await service.simulateConnectionDrop(shouldSucceedOnRetry: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(statuses, contains(MqttConnectionStatus.reconnecting));
      expect(statuses.last, equals(MqttConnectionStatus.connected));

      await sub.cancel();
    });

    test('simulates auto-reconnect failure exhausting retries to error',
        () async {
      await service.connect(
        host: 'broker.lumivo.internal',
        clientId: 'client-test-fail',
      );

      final statuses = <MqttConnectionStatus>[];
      final sub = service.statusStream.listen(statuses.add);

      await service.simulateConnectionDrop(shouldSucceedOnRetry: false);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(statuses, contains(MqttConnectionStatus.reconnecting));
      expect(statuses.last, equals(MqttConnectionStatus.error));

      await sub.cancel();
    });

    test('increments ping count on keepalive interval', () async {
      await service.connect(
        host: 'broker.lumivo.internal',
        clientId: 'client-test-6',
      );

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(service.pingCount, greaterThan(0));
      expect(service.lastPingTime, isNotNull);
    });
  });
}
