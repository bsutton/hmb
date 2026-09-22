// ignore_for_file: async_return_with_no_await

@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/milestone/edit_milestone_payment.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:material_ui/material_ui.dart';
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
      if (find.textContaining(text).evaluate().isNotEmpty ||
          find.text(text).evaluate().isNotEmpty) {
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

  testWidgets('progress invoices are deducted before redistribution', (
    tester,
  ) async {
    final quoteId = await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
      );
      final quoteId = await DaoQuote().insert(
        Quote.forInsert(
          jobId: job.id,
          summary: 'Progress',
          description: '',
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
      for (var number = 1; number <= 2; number++) {
        final milestone = Milestone.forInsert(
          quoteId: quoteId,
          milestoneNumber: number,
          paymentAmount: Money.fromInt(10000, isoCode: 'AUD'),
          paymentPercentage: Percentage.fromInt(33),
          milestoneDescription: 'Payment $number',
        );
        if (number == 1) {
          milestone.invoiceId = invoiceId;
        }
        await DaoMilestone().insert(milestone);
      }
      return quoteId;
    });
    await tester.pumpWidget(
      MaterialApp(home: EditMilestonesScreen(quoteId: quoteId!)),
    );
    await waitForText(tester, 'Quote Total');
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Add Milestone'));
    });
    // The third tile can be below the lazy list's viewport. Wait for the DAO
    // write rather than requiring that off-screen tile to be built.
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      final ready = await tester.runAsync(() async {
        final rows = await DaoMilestone().getByQuoteId(quoteId);
        return rows.length == 3 &&
            rows.every((row) => row.paymentAmount.minorUnits.toInt() == 10000);
      });
      if (ready!) {
        break;
      }
    }
    await tester.runAsync(() async {
      final milestones = await DaoMilestone().getByQuoteId(quoteId);
      expect(milestones, hasLength(3));
      expect(
        milestones.map((m) => m.paymentAmount.minorUnits.toInt()),
        everyElement(10000),
      );
    });
  });

  testWidgets('add milestone allowed before quote approval', (tester) async {
    final quoteId = await tester.runAsync(() async {
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
          totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
        ),
      );
      return quoteId;
    });
    await tester.pumpWidget(
      MaterialApp(home: EditMilestonesScreen(quoteId: quoteId!)),
    );
    await tester.pumpAndSettle();
    await waitForText(tester, 'Quote Total');

    final iconButtonFinder = find.ancestor(
      of: find.byIcon(Icons.add).first,
      matching: find.byType(IconButton),
    );
    await tester.tap(iconButtonFinder.first);
    await tester.pumpAndSettle();
    await waitForText(tester, 'Milestone 1');
    expect(find.text('Milestone 1'), findsOneWidget);
  });

  testWidgets('add milestone when approved', (tester) async {
    final quoteId = await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      return DaoQuote().insert(
        Quote.forInsert(
          jobId: job.id,
          summary: 'Quote',
          description: 'Quote description',
          totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
          state: QuoteState.approved,
        ),
      );
    });

    await tester.pumpWidget(
      MaterialApp(home: EditMilestonesScreen(quoteId: quoteId!)),
    );
    await tester.pumpAndSettle();
    await waitForText(tester, 'Quote Total');

    final iconButtonFinder = find.ancestor(
      of: find.byIcon(Icons.add).first,
      matching: find.byType(IconButton),
    );

    await tester.tap(iconButtonFinder.first);
    await tester.pumpAndSettle();
    await waitForText(tester, 'Milestone 1');
    expect(find.text('Milestone 1'), findsOneWidget);
  });
}
