import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/invoicing/dialog_select_tasks.dart';
import 'package:hmb/ui/invoicing/invoice_options.dart';
import 'package:money2/money2.dart';

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

  testWidgets('fixed price quote selection can include booking fee', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );
      final contact = (await DaoContact().getById(job.billingContactId))!;
      final task = Task.forInsert(
        jobId: job.id,
        name: 'Fixed price task',
        description: '',
        status: TaskStatus.approved,
      );
      await DaoTask().insert(task);
      return (job, contact, task);
    }))!;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<InvoiceOptions>(
              context: context,
              builder: (_) => DialogTaskSelection(
                job: fixture.$1,
                contact: fixture.$2,
                title: 'Tasks to Quote',
                forQuote: true,
                taskSelectors: [
                  TaskSelector(
                    fixture.$3,
                    fixture.$3.name,
                    Money.fromInt(25000, isoCode: 'AUD'),
                  ),
                ],
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await waitForText(tester, 'Bill booking Fee');

    expect(find.text('Bill booking Fee'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsWidgets);
  });
}
