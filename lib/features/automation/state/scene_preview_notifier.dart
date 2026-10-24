import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart' show devicesProvider;
import '../../../core/models/automation_rule.dart';
import '../../../core/models/device_command.dart';
import '../../../core/models/smart_device.dart';

class ScenePreviewItem {
  const ScenePreviewItem({
    required this.device,
    required this.action,
    required this.currentValue,
    required this.targetValue,
    required this.propertyName,
  });

  final SmartDevice? device;
  final DeviceAction action;
  final Object? currentValue;
  final Object? targetValue;
  final String propertyName;

  bool get willChange => currentValue != targetValue;
}

class ScenePreviewEngine {
  const ScenePreviewEngine._();

  static List<ScenePreviewItem> computePreview({
    required Scene scene,
    required List<SmartDevice> devices,
  }) {
    final deviceMap = {for (final d in devices) d.id: d};

    return scene.actions.map((action) {
      final device = deviceMap[action.deviceId];
      Object? current;
      Object? target = action.value;
      String propertyName;

      switch (action.commandType) {
        case DeviceCommandType.setPower:
          propertyName = 'Power';
          current = device?.isOn;
          break;
        case DeviceCommandType.setBrightness:
          propertyName = 'Brightness';
          current = device?.brightness;
          break;
        case DeviceCommandType.setTargetTemperature:
          propertyName = 'Target Temperature';
          current = device?.targetTemperature;
          break;
        case DeviceCommandType.setPosition:
          propertyName = 'Position';
          current = device?.position;
          break;
        case DeviceCommandType.setLock:
          propertyName = 'Lock';
          current = device?.isLocked;
          break;
        case DeviceCommandType.toggleLock:
          propertyName = 'Lock';
          current = device?.isLocked;
          target = !(device?.isLocked ?? false);
          break;
      }

      return ScenePreviewItem(
        device: device,
        action: action,
        currentValue: current,
        targetValue: target,
        propertyName: propertyName,
      );
    }).toList();
  }
}

final selectedSceneForPreviewProvider = StateProvider<Scene?>((ref) => null);

final scenePreviewProvider = Provider<List<ScenePreviewItem>>((ref) {
  final selectedScene = ref.watch(selectedSceneForPreviewProvider);
  if (selectedScene == null) return const [];

  final devicesAsync = ref.watch(devicesProvider);
  final devices = devicesAsync.value ?? const [];

  return ScenePreviewEngine.computePreview(
    scene: selectedScene,
    devices: devices,
  );
});

final scenePreviewFamily =
    Provider.family<List<ScenePreviewItem>, Scene>((ref, scene) {
  final devicesAsync = ref.watch(devicesProvider);
  final devices = devicesAsync.value ?? const [];

  return ScenePreviewEngine.computePreview(
    scene: scene,
    devices: devices,
  );
});
