@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/crud/system/system_billing_screen.dart';

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

  testWidgets('billing form avoids duplicate scroll padding', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SystemBillingScreen()));
    await tester.pumpAndSettle();

    final paddedScroll = find.byWidgetPredicate(
      (widget) =>
          widget is Padding &&
          widget.padding == const EdgeInsets.all(16) &&
          widget.child is ListView,
    );

    expect(paddedScroll, findsNothing);
  });
}
