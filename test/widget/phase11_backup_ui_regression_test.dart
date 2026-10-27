import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/backup/presentation/backup_restore_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  testWidgets(
      'REGRESSION: actual backup screen export-import must preserve second-home device fields',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final manager = HomePersistenceManager(storage: StorageAdapterImpl());
    const original = SmartDevice(
      id: 'independent-garden-light',
      name: 'QA Garden Light',
      roomId: 'Garden',
      homeId: 'home-suburban',
      type: DeviceType.light,
      isOn: true,
      brightness: 37,
      powerUsageWatts: 18.5,
      targetTemperature: 19.0,
      isLocked: false,
      customData: {'qaMarker': 'retain-me'},
    );
    final repo = MockDeviceRepository(
      responseDelay: Duration.zero,
      initialDevices: [original],
      persistenceManager: manager,
    );
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repo),
          homePersistenceProvider.overrideWithValue(manager),
          appLocalizationsProvider
              .overrideWithValue(AppLocalizations(const Locale('en'))),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BackupRestoreScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final export = find.byKey(const Key('export_backup_button'));
    await tester.ensureVisible(export);
    await tester.tap(export);
    await tester.pumpAndSettle();
    final import = find.byKey(const Key('import_backup_button'));
    await tester.ensureVisible(import);
    await tester.tap(import);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('backup_preview_dialog')),
      findsOneWidget,
      reason:
          'A valid self-export must reach the real preview, not a mocked callback.',
    );
    final confirm = find.byKey(const Key('confirm_restore_backup_button'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    final restored = repo.devices.singleWhere((d) => d.id == original.id);
    expect(
      restored.homeId,
      original.homeId,
      reason:
          'Self round-trip must not move home-suburban device to home-default.',
    );
    expect(
      restored.toJson(),
      original.toJson(),
      reason:
          'All device properties must survive an unmodified export/import.',
    );
  });
}
