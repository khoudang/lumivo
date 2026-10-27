import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/room.dart';
import 'package:lumivo/features/rooms/state/rooms_notifier.dart';
import 'package:lumivo/services/backup/backup_validation_service.dart';

void main() {
  test('REGRESSION QA-03: same room name in different homes must preserve both', () async {
    final notifier = RoomsNotifier(const [
      Room(id: 'a-living', name: 'Living Room', homeId: 'home-a'),
    ]);
    addTearDown(notifier.dispose);
    await notifier.addRoom(const Room(
        id: 'b-living', name: 'Living Room', homeId: 'home-b'));
    expect(notifier.state.map((r) => r.id),
        containsAll(['a-living', 'b-living']),
        reason: 'A normal cross-home duplicate name must not delete home A room.');
  });

  test('REGRESSION QA-05: wrong schema type must return validation error, not throw', () {
    expect(() => BackupValidationService.validate('{"schemaVersion":"6"}'),
        returnsNormally,
        reason: 'Untrusted backup type errors must be handled at validation boundary.');
  });

  test('Strict ID types: non-string IDs report validation errors', () {
    final payload = '''
    {
      "schemaVersion": 6,
      "homes": [{"id": 123, "name": "Main Home"}],
      "rooms": [{"id": 456, "name": "Living", "homeId": "home-1"}],
      "devices": [{"id": 789, "name": "Light", "roomId": "room-1"}],
      "scenes": [{"id": 101, "name": "Night Mode"}],
      "automations": [{"id": 202, "name": "Motion Sensor"}]
    }
    ''';
    final result = BackupValidationService.validate(payload);
    expect(result.isValid, isFalse);
    expect(result.errors.any((e) => e.contains('Home ID must be a string')), isTrue);
    expect(result.errors.any((e) => e.contains('Room ID must be a string')), isTrue);
    expect(result.errors.any((e) => e.contains('Device ID must be a string')), isTrue);
    expect(result.errors.any((e) => e.contains('Scene ID must be a string')), isTrue);
    expect(result.errors.any((e) => e.contains('Automation ID must be a string')), isTrue);
  });

  test('Referential integrity: device home and room home mismatch', () {
    final payload = '''
    {
      "schemaVersion": 6,
      "homes": [{"id": "home-a", "name": "Home A"}, {"id": "home-b", "name": "Home B"}],
      "rooms": [{"id": "room-b", "name": "Bedroom", "homeId": "home-b"}],
      "devices": [{"id": "dev-1", "name": "Lamp", "roomId": "room-b", "homeId": "home-a"}]
    }
    ''';
    final result = BackupValidationService.validate(payload);
    expect(result.isValid, isFalse);
    expect(
      result.errors.any((e) => e.contains('Device "dev-1" belongs to home "home-a" but references room "room-b" belonging to home "home-b".')),
      isTrue,
    );
  });

  test('Referential integrity: scene and automation cross-home device action mismatch', () {
    final payload = '''
    {
      "schemaVersion": 6,
      "homes": [{"id": "home-a", "name": "Home A"}, {"id": "home-b", "name": "Home B"}],
      "rooms": [
        {"id": "room-a", "name": "Living", "homeId": "home-a"},
        {"id": "room-b", "name": "Bedroom", "homeId": "home-b"}
      ],
      "devices": [
        {"id": "dev-a", "name": "Light A", "roomId": "room-a", "homeId": "home-a"},
        {"id": "dev-b", "name": "Sensor B", "roomId": "room-b", "homeId": "home-b"}
      ],
      "scenes": [
        {
          "id": "scene-a",
          "name": "Scene A",
          "homeId": "home-a",
          "actions": [{"deviceId": "dev-b", "commandType": "setPower", "value": true}]
        }
      ],
      "automations": [
        {
          "id": "auto-a",
          "name": "Auto A",
          "homeId": "home-a",
          "sensorDeviceId": "dev-b",
          "actions": [{"deviceId": "dev-b", "commandType": "setPower", "value": false}]
        }
      ]
    }
    ''';
    final result = BackupValidationService.validate(payload);
    expect(result.isValid, isFalse);
    expect(
      result.errors.any((e) => e.contains('Scene "scene-a" belongs to home "home-a" but action targets device "dev-b" belonging to home "home-b".')),
      isTrue,
    );
    expect(
      result.errors.any((e) => e.contains('Automation "auto-a" belongs to home "home-a" but action targets device "dev-b" belonging to home "home-b".')),
      isTrue,
    );
    expect(
      result.errors.any((e) => e.contains('Automation "auto-a" belongs to home "home-a" but sensor references device "dev-b" belonging to home "home-b".')),
      isTrue,
    );
  });
}
