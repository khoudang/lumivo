import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/home.dart';
import 'package:lumivo/core/models/user_profile.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 3 Persistence Migration & Demo State Unit Tests', () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager manager;

    setUp(() {
      storage = StorageAdapterImpl();
      manager = HomePersistenceManager(storage: storage);
    });

    test(
        'V2 -> V3 schema migration preserves data and injects homes/profile/energy',
        () async {
      // 1. Prepare raw Schema V2 payload without homeId or homes or userProfile
      final v2Payload = {
        'schemaVersion': 2,
        'rooms': [
          {
            'id': 'Living Room',
            'name': 'Living Room',
            'iconName': 'living_room',
            'description': 'Main living space',
          },
          {
            'id': 'Master Bedroom',
            'name': 'Master Bedroom',
            'iconName': 'bedroom',
            'description': 'Master suite',
          },
        ],
        'devices': [
          {
            'id': 'v2-bulb-1',
            'name': 'Living Chandelier',
            'roomId': 'Living Room',
            'type': 'light',
            'isOn': true,
            'brightness': 90,
            'isFavorite': true,
            'favoriteOrder': 1,
            'customIcon': 'lamp',
          },
          {
            'id': 'v2-ac-1',
            'name': 'Master AC',
            'roomId': 'Master Bedroom',
            'type': 'ac',
            'isOn': false,
            'targetTemperature': 21.0,
          },
        ],
        'scenes': [
          {
            'id': 'v2-scene-1',
            'name': 'Relax',
            'iconName': 'spa',
            'actions': [
              {
                'deviceId': 'v2-bulb-1',
                'commandType': 'setBrightness',
                'value': 30,
              }
            ],
          }
        ],
        'automations': [
          {
            'id': 'v2-rule-1',
            'name': 'Night Dim',
            'isEnabled': true,
            'triggerType': 'schedule',
            'timeOfDay': '22:30',
            'actions': [
              {
                'deviceId': 'v2-bulb-1',
                'commandType': 'setPower',
                'value': false,
              }
            ],
          }
        ],
      };

      // Stored under V2 storage key
      await storage.setString(
        HomePersistenceManager.v2StorageKey,
        jsonEncode(v2Payload),
      );

      // 2. Load Home State triggers auto-migration
      final migrated = await manager.loadHomeState();

      // 3. Verify Schema V3 upgrades
      expect(migrated.schemaVersion, greaterThanOrEqualTo(3));
      expect(HomePersistenceManager.schemaVersion, greaterThanOrEqualTo(3));

      // Injects default homes if none present
      expect(migrated.homes.length, greaterThanOrEqualTo(2));
      final homeDefault =
          migrated.homes.firstWhere((h) => h.id == 'home-default');
      expect(homeDefault.name, 'Downtown Penthouse');
      expect(homeDefault.isCurrent, isTrue);
      expect(homeDefault.tariffRate, 0.16);

      final homeSuburban =
          migrated.homes.firstWhere((h) => h.id == 'home-suburban');
      expect(homeSuburban.name, 'Suburban Villa');
      expect(homeSuburban.isCurrent, isFalse);
      expect(homeSuburban.tariffRate, 0.14);

      expect(migrated.currentHomeId, 'home-default');

      // Tags all existing devices, rooms, scenes, automations with homeId = 'home-default'
      expect(migrated.devices.length, 2);
      final bulb = migrated.devices.firstWhere((d) => d.id == 'v2-bulb-1');
      expect(bulb.homeId, 'home-default');
      expect(bulb.name, 'Living Chandelier');
      expect(bulb.isFavorite, isTrue);
      expect(bulb.favoriteOrder, 1);
      expect(bulb.customIcon, 'lamp');

      final ac = migrated.devices.firstWhere((d) => d.id == 'v2-ac-1');
      expect(ac.homeId, 'home-default');
      expect(ac.targetTemperature, 21.0);

      for (final room in migrated.rooms) {
        expect(room.homeId, 'home-default');
      }

      for (final scene in migrated.scenes) {
        expect(scene.homeId, 'home-default');
      }

      for (final rule in migrated.automations) {
        expect(rule.homeId, 'home-default');
      }

      // Adds default UserProfile ("Alex Mercer")
      expect(migrated.userProfile.name, 'Alex Mercer');
      expect(migrated.userProfile.email, 'alex.mercer@lumivo.io');
      expect(migrated.userProfile.themeMode, 'dark');

      // Adds initial energy samples / history
      expect(migrated.energySamples.isNotEmpty, isTrue);
      expect(migrated.energySamples.length, 24);

      // Cleans up legacy/v2 keys and persists to V3 key
      expect(
        await storage.getString(HomePersistenceManager.v2StorageKey),
        isNull,
      );
      expect(
        await storage.getString(HomePersistenceManager.storageKey),
        isNotNull,
      );
    });

    test('resetDemoData restores multi-home, profile, and energy state',
        () async {
      // Mutate storage with arbitrary corrupted or partial data
      await storage.setString(
        HomePersistenceManager.storageKey,
        jsonEncode({'schemaVersion': 1}),
      );

      // Perform reset
      final demoState = await manager.resetDemoData();

      // Verify Schema version 3
      expect(demoState.schemaVersion, greaterThanOrEqualTo(3));

      // Verify 2 homes: Downtown Penthouse and Suburban Villa
      expect(demoState.homes.length, 2);
      final defaultHome =
          demoState.homes.firstWhere((h) => h.id == 'home-default');
      expect(defaultHome.name, 'Downtown Penthouse');
      expect(defaultHome.isCurrent, isTrue);
      expect(defaultHome.tariffRate, 0.16);

      final suburbanHome =
          demoState.homes.firstWhere((h) => h.id == 'home-suburban');
      expect(suburbanHome.name, 'Suburban Villa');
      expect(suburbanHome.isCurrent, isFalse);
      expect(suburbanHome.tariffRate, 0.14);

      // Downtown Penthouse with 7 devices across 3 rooms
      final penthouseDevices =
          demoState.devices.where((d) => d.homeId == 'home-default').toList();
      expect(penthouseDevices.length, 7);
      final penthouseRooms =
          penthouseDevices.map((d) => d.roomId).toSet().toList();
      expect(penthouseRooms.length, 3);
      expect(penthouseRooms, contains('Living Room'));
      expect(penthouseRooms, contains('Bedroom'));
      expect(penthouseRooms, contains('Kitchen'));

      // Suburban Villa with 2 devices
      final suburbanDevices =
          demoState.devices.where((d) => d.homeId == 'home-suburban').toList();
      expect(suburbanDevices.length, 2);
      final suburbanRooms =
          suburbanDevices.map((d) => d.roomId).toSet().toList();
      expect(suburbanRooms, contains('Garden'));
      expect(suburbanRooms, contains('Garage'));

      // Total devices = 9
      expect(demoState.devices.length, 9);

      // User profile restored
      expect(demoState.userProfile.name, 'Alex Mercer');
      expect(demoState.userProfile.email, 'alex.mercer@lumivo.io');
      expect(demoState.userProfile.language, 'en');

      // Energy history populated
      expect(demoState.energySamples.length, 24);
      expect(demoState.energySamples.first.energyKWh, greaterThan(0.0));

      // Default scenes and automations
      expect(demoState.scenes.length, greaterThanOrEqualTo(5));
      expect(demoState.automations.length, greaterThanOrEqualTo(4));

      // Reloading from storage returns identical multi-home state
      final reloaded = await manager.loadHomeState();
      expect(reloaded.schemaVersion, greaterThanOrEqualTo(3));
      expect(reloaded.homes.length, 2);
      expect(reloaded.devices.length, 9);
      expect(reloaded.userProfile.name, 'Alex Mercer');
    });

    test('Saving and loading specific domain slices persists correctly in V3',
        () async {
      await manager.resetDemoData();

      // 1. Update Homes
      const customHome = Home(
        id: 'home-mountain',
        name: 'Mountain Cabin',
        tariffRate: 0.12,
      );
      await manager.saveHomes([
        ...HomePersistenceManager.defaultHomes,
        customHome,
      ]);

      // 2. Update Current Home Id
      await manager.saveCurrentHomeId('home-mountain');

      // 3. Update UserProfile
      const updatedProfile = UserProfile(
        id: 'user-custom',
        name: 'Alexandra Mercer',
        language: 'vi',
        themeMode: 'oled',
      );
      await manager.saveUserProfile(updatedProfile);

      // Reload
      final reloaded = await manager.loadHomeState();
      expect(reloaded.homes.any((h) => h.id == 'home-mountain'), isTrue);
      expect(reloaded.currentHomeId, 'home-mountain');
      expect(reloaded.userProfile.name, 'Alexandra Mercer');
      expect(reloaded.userProfile.language, 'vi');
      expect(reloaded.userProfile.themeMode, 'oled');
    });
  });
}
