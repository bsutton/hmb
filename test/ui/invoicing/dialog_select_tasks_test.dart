import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/invoicing/dialog_select_tasks.dart';
import 'package:money2/money2.dart';

import '../../dao/invoice/utility.dart';
import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitForText(
    WidgetTester tester,
    String text, {
    int attempts = 30,
  }) async {
    for (var i = 0; i < attempts; i++) {
      if (find.text(text).evaluate().isNotEmpty) {
        return;
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    throw TestFailure('Timed out waiting for text: $text');
  }

  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('fixed price quote can include booking fee', (tester) async {
    final dialog = await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );
      final task = await createTask(job, 'Quote task');
      final contact = await DaoContact().getBillingContactByJob(job);

      return DialogTaskSelection(
        job: job,
        contact: contact!,
        title: 'Tasks to Quote',
        forQuote: true,
        taskSelectors: [
          TaskSelector(task, task.name, Money.fromInt(25000, isoCode: 'AUD')),
        ],
      );
    });

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: dialog)));
    await tester.pumpAndSettle();
    await waitForText(tester, 'Select All');

    expect(find.text('Bill booking Fee'), findsOneWidget);
  });

  testWidgets('fixed price invoice does not show booking fee toggle', (
    tester,
  ) async {
    final dialog = await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );
      final task = await createTask(job, 'Invoice task');
      final contact = await DaoContact().getBillingContactByJob(job);

      return DialogTaskSelection(
        job: job,
        contact: contact!,
        title: 'Tasks to Invoice',
        forQuote: false,
        taskSelectors: [
          TaskSelector(task, task.name, Money.fromInt(25000, isoCode: 'AUD')),
        ],
      );
    });

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: dialog)));
    await tester.pumpAndSettle();
    await waitForText(tester, 'Select All');

    expect(find.text('Bill booking Fee'), findsNothing);
  });
}
