import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/milestone/list_milestone_screen.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:money2/money2.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

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

  testWidgets('summary counts exclude voided milestones', (tester) async {
    await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      final quoteId = await DaoQuote().insert(
        Quote.forInsert(
          jobId: job.id,
          summary: 'Quote',
          description: 'Quote description',
          totalAmount: Money.fromInt(30000, isoCode: 'AUD'),
          state: QuoteState.approved,
        ),
      );

      await DaoMilestone().insert(
        Milestone.forInsert(
          quoteId: quoteId,
          milestoneNumber: 1,
          paymentAmount: Money.fromInt(10000, isoCode: 'AUD'),
          paymentPercentage: Percentage.fromInt(33),
        ),
      );

      await DaoMilestone().insert(
        Milestone.forInsert(
          quoteId: quoteId,
          milestoneNumber: 2,
          paymentAmount: Money.fromInt(20000, isoCode: 'AUD'),
          paymentPercentage: Percentage.fromInt(67),
          voided: true,
        ),
      );
    });
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ListMilestoneScreen())),
    );
    await tester.pumpAndSettle();
    await waitForText(tester, 'Milestones: 1');

    expect(find.text('Milestones: 1'), findsOneWidget);
    expect(find.text('Voided Milestones: 1'), findsOneWidget);
    expect(find.text('Invoiced Milestones: 0'), findsOneWidget);
    expect(
      find.text('Total Value: ${Money.fromInt(10000, isoCode: 'AUD')}'),
      findsOneWidget,
    );
  });

  testWidgets('hides summaries where all active milestones are invoiced', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      final quoteId = await DaoQuote().insert(
        Quote.forInsert(
          jobId: job.id,
          summary: 'Fully invoiced quote',
          description: 'Quote description',
          totalAmount: Money.fromInt(30000, isoCode: 'AUD'),
          state: QuoteState.approved,
        ),
      );

      final invoiceId = await DaoInvoice().insert(
        Invoice.forInsert(
          jobId: job.id,
          dueDate: LocalDate.today(),
          totalAmount: Money.fromInt(10000, isoCode: 'AUD'),
          billingContactId: job.billingContactId,
        ),
      );

      await DaoMilestone().insert(
        Milestone.forInsert(
          quoteId: quoteId,
          milestoneNumber: 1,
          paymentAmount: Money.fromInt(10000, isoCode: 'AUD'),
          paymentPercentage: Percentage.fromInt(100),
          invoiceId: invoiceId,
        ),
      );
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ListMilestoneScreen())),
    );
    await tester.pumpAndSettle();

    await waitForText(
      tester,
      'No milestones found - create milestone payments from the Billing/Quote screen.',
    );
    expect(find.text('Fully invoiced quote'), findsNothing);
  });
}
