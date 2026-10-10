@Tags(['flutter'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/crud/system/google_calendar_integration_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../../util/settings_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUpAll(prepareSettingsTest);
  setUp(() async {
    await setupTestDb();
    await resetSettingsForTest();
  });
  tearDown(tearDownTestDb);

  for (final scale in [1.0, 2.0]) {
    testWidgets('pending cleanup is visible at 320px and scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await testDb!.execute(
          File('test/sql/cancelled_schedule.sql').readAsStringSync(),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const GoogleCalendarIntegrationScreen(),
        ),
      );
      await pumpUntilFound(
        tester,
        find.textContaining('HMB can copy schedule events'),
      );
      await tester.scrollUntilVisible(
        find.text('Retry cancelled booking cleanup'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Retry cancelled booking cleanup'), findsOneWidget);
      expect(
        find.textContaining('cancelled booking(s) still need'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
