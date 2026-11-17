import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/app.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/features/dashboard/widgets/room_selector.dart';
import 'package:lumivo/features/dashboard/widgets/brightness_slider_card.dart';
import 'package:lumivo/features/dashboard/widgets/device_card.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  testWidgets('saved reduced motion disables home state-transition animations',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MockDeviceRepository(responseDelay: Duration.zero);
    addTearDown(repo.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      deviceRepositoryProvider.overrideWithValue(repo),
      userProfileProvider.overrideWith((ref) => UserProfileNotifier(
            HomePersistenceManager.defaultUserProfile
                .copyWith(reducedMotion: true),
          )),
    ], child: const LumivoApp()));
    await tester.pumpAndSettle();
    expect(
        MediaQuery.disableAnimationsOf(
            tester.element(find.byType(DeviceCard).first)),
        isTrue);
    // Check app-owned controls, not Material IconButton's implementation
    // detail animations or deferred legacy screens in the IndexedStack.
    for (final type in [DeviceCard, RoomSelector, BrightnessSliderCard]) {
      final controls = find.descendant(
        of: find.byType(type),
        matching: find.byType(AnimatedContainer),
      );
      final containers = tester.widgetList<AnimatedContainer>(controls);
      expect(containers, isNotEmpty);
      for (final container in containers) {
        expect(container.duration, Duration.zero);
      }
    }
  });
}
