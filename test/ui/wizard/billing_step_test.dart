import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/crud/system/system_billing_screen.dart';
import 'package:toastification/toastification.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../../util/settings_test_helper.dart';

void main() {
  setUpAll(prepareSettingsTest);

  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('billing onboarding exposes tax jurisdiction', (tester) async {
    final key = GlobalKey<SystemBillingScreenState>();
    await tester.pumpWidget(_buildHarness(key));
    await _pumpBillingStep(tester, key);

    expect(find.text('Tax Jurisdiction'), findsOneWidget);
    expect(find.textContaining('Custom tax scheme'), findsOneWidget);
    expect(find.text('Tax Registered'), findsOneWidget);
    expect(find.text('PDF Tax Display'), findsNothing);
    await tester.pump();
  });
}

Widget _buildHarness(GlobalKey<SystemBillingScreenState> key) =>
    ToastificationWrapper(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SystemBillingScreen(key: key, showButtons: false),
          ),
        ),
      ),
    );

Future<void> _pumpBillingStep(
  WidgetTester tester,
  GlobalKey<SystemBillingScreenState> key,
) async {
  expect(key.currentState, isNotNull);
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    final exception = tester.takeException();
    if (exception != null) {
      fail('Billing onboarding failed to initialise: $exception');
    }
    if (find.text('Tax Jurisdiction').evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 1));
      return;
    }
  }
  fail('Billing onboarding did not render the form.');
}
