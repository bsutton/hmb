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

  testWidgets('does not show per-task reject controls on quote details', (
    tester,
  ) async {
    late Job job;
    late int quoteId;
    late int groupId;

    await tester.runAsync(() async {
      await setupTestDb();

      job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      final task = await createTask(job, 'Task 1');

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
    await waitForText(tester, 'Line 1');

    expect(find.text('Reject'), findsNothing);
    expect(find.text('Unreject'), findsNothing);
    expect(find.text('Reject Quote Group'), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
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

    // Invoice action availability is asserted above via button presence.
    // The billing-contact dialog flow is covered separately and can be
    // timing-sensitive in this integration-style widget test.
  });
}
