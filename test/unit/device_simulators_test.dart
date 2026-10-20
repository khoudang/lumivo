import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/simulation/device_simulators/device_simulators.dart';

void main() {
  group('Device Simulators Unit Tests', () {
    group('BulbSimulator', () {
      test(
          'computes 9W * (brightness / 100) when On, and 0.2W standby when Off',
          () {
        final bulb = SmartDevice(
          id: 'bulb-1',
          name: 'Living Room Light',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: true,
          brightness: 100,
        );

        final sim = BulbSimulator(bulb);
        expect(sim.powerUsageWatts, 9.0);

        sim.setBrightness(50);
        expect(sim.powerUsageWatts, 4.5);

        expect(BulbSimulator.calculatePower(isOn: true, brightness: 0), 0.0);

        sim.setBrightness(0);
        // Brightness 0 turns bulb off, entering standby (0.2W)
        expect(sim.powerUsageWatts, 0.2);

        sim.setPower(false);
        expect(sim.powerUsageWatts, 0.2);

        sim.setPower(true);
        sim.setBrightness(80);
        expect(sim.powerUsageWatts, closeTo(7.2, 0.001));

        final ticked = sim.tick(const Duration(minutes: 1));
        expect(ticked.powerUsageWatts, closeTo(7.2, 0.001));
      });
    });

    group('FanSimulator', () {
      test(
          'computes Low (15W), Medium (35W), High (55W) when On, 0.5W standby when Off',
          () {
        final fan = SmartDevice(
          id: 'fan-1',
          name: 'Living Room Fan',
          roomId: 'Living Room',
          type: DeviceType.fan,
          isOn: true,
        );

        final sim = FanSimulator(fan);
        // Default speed is medium
        expect(sim.powerUsageWatts, 35.0);

        sim.setSpeed(FanSpeed.low);
        expect(sim.powerUsageWatts, 15.0);

        sim.setSpeed(FanSpeed.high);
        expect(sim.powerUsageWatts, 55.0);

        sim.setPower(false);
        expect(sim.powerUsageWatts, 0.5);

        sim.setPower(true);
        expect(sim.powerUsageWatts, 55.0);
      });
    });

    group('AcSimulator', () {
      test('power is 1200W when active (On) and 5W standby when Off', () {
        final ac = SmartDevice(
          id: 'ac-1',
          name: 'Master AC',
          roomId: 'Bedroom',
          type: DeviceType.ac,
          isOn: true,
          targetTemperature: 22.0,
          currentTemperature: 28.0,
        );

        final sim = AcSimulator(ac);
        expect(sim.powerUsageWatts, 1200.0);

        sim.setPower(false);
        expect(sim.powerUsageWatts, 5.0);
      });

      test(
          'pulls room temperature toward targetTemperature by 0.05°C per virtual minute',
          () {
        final ac = SmartDevice(
          id: 'ac-1',
          name: 'Master AC',
          roomId: 'Bedroom',
          type: DeviceType.ac,
          isOn: true,
          targetTemperature: 22.0,
          currentTemperature: 28.0,
        );

        final sim = AcSimulator(ac);

        // 10 virtual minutes -> 0.05 * 10 = 0.50°C drop -> 27.50°C
        var updated = sim.tick(const Duration(minutes: 10));
        expect(updated.currentTemperature, closeTo(27.5, 0.001));

        // Another 30 virtual minutes -> 0.05 * 30 = 1.50°C drop -> 26.00°C
        updated = sim.tick(const Duration(minutes: 30));
        expect(updated.currentTemperature, closeTo(26.0, 0.001));

        // Heating pull test: current is 20°C, target is 22°C
        sim.updateDevice(updated.copyWith(currentTemperature: 20.0));
        // 20 virtual minutes -> 0.05 * 20 = 1.00°C rise -> 21.00°C
        updated = sim.tick(const Duration(minutes: 20));
        expect(updated.currentTemperature, closeTo(21.0, 0.001));

        // Overshoot prevention: pull 100 minutes, should stop at exactly target 22.0°C
        updated = sim.tick(const Duration(minutes: 100));
        expect(updated.currentTemperature, 22.0);
      });
    });

    group('SocketSimulator', () {
      test('computes 120W when On, 0W when Off', () {
        final socket = SmartDevice(
          id: 'socket-1',
          name: 'Coffee Maker Plug',
          roomId: 'Kitchen',
          type: DeviceType.socket,
          isOn: true,
        );

        final sim = SocketSimulator(socket);
        expect(sim.powerUsageWatts, 120.0);

        sim.setPower(false);
        expect(sim.powerUsageWatts, 0.0);

        sim.setPower(true);
        expect(sim.powerUsageWatts, 120.0);
      });
    });

    group('CurtainSimulator', () {
      test('simulates position transition over virtual seconds', () {
        final curtain = SmartDevice(
          id: 'curtain-1',
          name: 'Living Room Curtains',
          roomId: 'Living Room',
          type: DeviceType.curtain,
          isOn: true,
          position: 0,
        );

        // 10% per virtual second
        final sim = CurtainSimulator(curtain, speedPercentPerSecond: 10.0);
        expect(sim.device.position, 0);
        expect(sim.isMoving, isFalse);
        expect(sim.powerUsageWatts, 0.5);

        // Target: 50%
        sim.setTargetPosition(50);
        expect(sim.isMoving, isTrue);
        expect(sim.powerUsageWatts, 15.0);

        // Tick 2 virtual seconds -> moves 20%
        var updated = sim.tick(const Duration(seconds: 2));
        expect(updated.position, 20);
        expect(sim.isMoving, isTrue);

        // Tick 3 more virtual seconds -> reaches 50% and stops
        updated = sim.tick(const Duration(seconds: 3));
        expect(updated.position, 50);
        expect(sim.isMoving, isFalse);
        expect(sim.powerUsageWatts, 0.5);
      });
    });

    group('LockSimulator', () {
      test('auto-locks after autoLockDelay when unlocked', () {
        final lock = SmartDevice(
          id: 'lock-1',
          name: 'Front Door Lock',
          roomId: 'Hallway',
          type: DeviceType.lock,
          isOn: true,
          isLocked: true,
        );

        final sim = LockSimulator(
          lock,
          autoLockDelay: const Duration(seconds: 30),
        );
        expect(sim.device.isLocked, isTrue);

        sim.unlock();
        expect(sim.device.isLocked, isFalse);

        // Advance 15 seconds (not auto-locked yet)
        var updated = sim.tick(const Duration(seconds: 15));
        expect(updated.isLocked, isFalse);

        // Advance another 16 seconds (total 31s > 30s autoLockDelay) -> auto-locks!
        updated = sim.tick(const Duration(seconds: 16));
        expect(updated.isLocked, isTrue);
      });
    });

    group('SensorSimulator', () {
      test(
          'computes diurnal temperature (22°C - 31°C) and humidity (45% - 75%)',
          () {
        final morningTime =
            DateTime(2026, 10, 20, 3, 0, 0); // ~03:00 (coldest, wettest)
        final afternoonTime =
            DateTime(2026, 10, 20, 15, 0, 0); // ~15:00 (hottest, driest)

        final morningTemp =
            SensorSimulator.computeDiurnalTemperature(morningTime);
        final morningHumidity =
            SensorSimulator.computeDiurnalHumidity(morningTime);

        final afternoonTemp =
            SensorSimulator.computeDiurnalTemperature(afternoonTime);
        final afternoonHumidity =
            SensorSimulator.computeDiurnalHumidity(afternoonTime);

        expect(morningTemp, closeTo(22.0, 0.5));
        expect(morningHumidity, closeTo(75.0, 0.5));

        expect(afternoonTemp, closeTo(31.0, 0.5));
        expect(afternoonHumidity, closeTo(45.0, 0.5));

        // Test throughout all 24 hours that values remain strictly within bounds
        for (var h = 0; h < 24; h++) {
          final t = DateTime(2026, 10, 20, h, 0, 0);
          final temp = SensorSimulator.computeDiurnalTemperature(t);
          final hum = SensorSimulator.computeDiurnalHumidity(t);

          expect(temp, inInclusiveRange(22.0, 31.0));
          expect(hum, inInclusiveRange(45.0, 75.0));
        }
      });

      test('adjusts sensor readings when AC is active in room', () {
        final sensor = SmartDevice(
          id: 'sensor-1',
          name: 'Living Room Sensor',
          roomId: 'Living Room',
          type: DeviceType.sensor,
          isOn: true,
          currentTemperature: 29.0,
          currentHumidity: 65.0,
        );

        final sim = SensorSimulator(sensor);
        final time = DateTime(2026, 10, 20, 14, 0, 0); // hot afternoon

        // Tick with active AC targeting 22°C
        final ticked = sim.tick(
          const Duration(minutes: 5),
          context: {
            'virtualTime': time,
            'acTemperature': 22.0,
            'isAcActive': true,
          },
        );

        // Reading should be pulled closer to 22°C than the unconditioned ambient (~30°C)
        expect(ticked.currentTemperature, lessThan(26.0));
        expect(ticked.currentHumidity, lessThanOrEqualTo(65.0));
      });
    });
  });
}
