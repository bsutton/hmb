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
    await _pumpBillingScreen(tester);

    final paddedScroll = find.byWidgetPredicate(
      (widget) =>
          widget is Padding &&
          widget.padding == const EdgeInsets.all(16) &&
          widget.child is ListView,
    );

    expect(paddedScroll, findsNothing);
  });

  testWidgets('billing form starts close to actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SystemBillingScreen()));
    await _pumpBillingScreen(tester);

    final cancelBottom = tester.getBottomLeft(find.text('Cancel')).dy;
    final ratesTop = tester.getTopLeft(find.text('Rates')).dy;

    expect(ratesTop - cancelBottom, lessThan(50));
  });
}

Future<void> _pumpBillingScreen(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    final exception = tester.takeException();
    if (exception != null) {
      fail('Billing failed to initialise: $exception');
    }
    if (find.text('Rates').evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 1));
      return;
    }
  }
  fail('Billing did not render the form.');
}
