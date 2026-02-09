import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/quoting/quote_details_screen.dart';
import 'package:money2/money2.dart';

import '../../dao/invoice/utility.dart';
import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitForText(
    WidgetTester tester,
    String text, {
    int attempts = 20,
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

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder, warnIfMissed: false);
    await tester.pump();
  }

  Future<void> tapTextAsync(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.runAsync(() async {
      await tester.tap(finder, warnIfMissed: false);
    });
    await tester.pump();
  }

  testWidgets('reject quote group cancels task', (tester) async {
    late Job job;
    late Task task;
    late int quoteId;
    late int groupId;

    await tester.runAsync(() async {
      await setupTestDb();

      job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      task = await createTask(job, 'Task 1');

      quoteId = await DaoQuote().insert(
        Quote.forInsert(
          jobId: job.id,
          summary: 'Quote',
          description: 'Quote description',
          totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
          state: QuoteState.sent,
        ),
      );

      groupId = await DaoQuoteLineGroup().insert(
        QuoteLineGroup.forInsert(
          quoteId: quoteId,
          taskId: task.id,
          name: task.name,
        ),
      );

      await DaoQuoteLine().insert(
        QuoteLine.forInsert(
          quoteId: quoteId,
          quoteLineGroupId: groupId,
          description: 'Line 1',
          quantity: Fixed.fromInt(1),
          unitCharge: Money.fromInt(10000, isoCode: 'AUD'),
          lineTotal: Money.fromInt(10000, isoCode: 'AUD'),
        ),
      );
    });
    addTearDown(() async {
      await tearDownTestDb();
    });

    await tester.pumpWidget(
      MaterialApp(home: QuoteDetailsScreen(quoteId: quoteId)),
    );
    expect(tester.takeException(), isNull);

    await waitForText(tester, 'Reject');
    await tester.tap(find.text('Reject'));
    expect(tester.takeException(), isNull);

    await waitForText(tester, 'Reject Quote Group');
    expect(find.text('Reject Quote Group'), findsOneWidget);
    expect(find.text('Reject this quote group and its task?'), findsOneWidget);

    await tester.tap(find.text('Reject'));

    late Task? updatedTask;
    await tester.runAsync(() async {
      updatedTask = await DaoTask().getById(task.id);
    });
    expect(updatedTask?.status, TaskStatus.cancelled);
  });

  testWidgets('create milestones and invoice actions show', (tester) async {
    late int quoteId;

    await tester.runAsync(() async {
      await setupTestDb();

      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      quoteId = await DaoQuote().insert(
        Quote.forInsert(
          jobId: job.id,
          summary: 'Quote',
          description: 'Quote description',
          totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
          state: QuoteState.approved,
        ),
      );
    });
    addTearDown(() async {
      await tearDownTestDb();
    });

    await tester.pumpWidget(
      MaterialApp(home: QuoteDetailsScreen(quoteId: quoteId)),
    );

    await waitForText(tester, 'Create Milestones');
    expect(find.text('Create Milestones'), findsOneWidget);
    expect(find.text('Create Invoice'), findsOneWidget);

    await tapText(tester, 'Create Milestones');

    await waitForText(tester, 'Edit Milestones');
    expect(find.text('Edit Milestones'), findsOneWidget);

    await tester.pageBack();

    await tapTextAsync(tester, 'Create Invoice');

    await waitForText(tester, 'Select Billing Contact');
    expect(find.text('Select Billing Contact'), findsOneWidget);
  });
}
