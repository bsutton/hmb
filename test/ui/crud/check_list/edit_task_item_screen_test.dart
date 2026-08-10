@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/job.dart';
import 'package:hmb/ui/crud/check_list/edit_task_item_screen.dart';
import 'package:hmb/ui/widgets/blocking_ui.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../../util/settings_test_helper.dart';

void main() {
  setUpAll(prepareSettingsTest);

  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('uses the standard blocking UI while loading system defaults', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            TaskItemEditScreen(
              parent: null,
              billingType: BillingType.timeAndMaterial,
              hourlyRate: MoneyEx.zero,
            ),
            const BlockingOverlay(),
          ],
        ),
      ),
    );

    expect(find.text('Loading...'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    for (var attempt = 0; attempt < 30; attempt++) {
      if (find.text('Description').evaluate().isNotEmpty) {
        break;
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Loading...'), findsNothing);
    expect(find.text('Add Task Item'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
