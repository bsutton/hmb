// ignore_for_file: async_return_with_no_await

@Tags(['flutter'])
library;

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/milestone/edit_milestone_payment.dart';
import 'package:hmb/ui/widgets/icons/hmb_add_button.dart';
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
    final state = tester.state<DeferredState<EditMilestonesScreen>>(
      find.byType(EditMilestonesScreen),
    );
    await runAsyncAndPump(tester, () => state.initialised);
    for (var i = 0; i < attempts; i++) {
      if (find.textContaining(text).evaluate().isNotEmpty ||
          find.text(text).evaluate().isNotEmpty) {
        return;
      }
      await runAsyncAndPump(tester, () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 20));
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
    final quoteId = await runAsyncAndPump(tester, () async {
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
      MaterialApp(home: EditMilestonesScreen(quoteId: quoteId)),
    );
    await waitForText(tester, 'Quote Total');
    await addMilestone(tester);
    await runAsyncAndPump(tester, () async {
      final milestones = await DaoMilestone().getByQuoteId(quoteId);
      expect(milestones, hasLength(3));
      expect(
        milestones.map((m) => m.paymentAmount.minorUnits.toInt()),
        everyElement(10000),
      );
    });
  });

  testWidgets('add milestone allowed before quote approval', (tester) async {
    final quoteId = await runAsyncAndPump(tester, () async {
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
      MaterialApp(home: EditMilestonesScreen(quoteId: quoteId)),
    );
    await tester.pumpAndSettle();
    await waitForText(tester, 'Quote Total');

    await addMilestone(tester);
    await tester.pumpAndSettle();
    await waitForText(tester, 'Milestone 1');
    expect(find.text('Milestone 1'), findsOneWidget);
  });

  testWidgets('add milestone when approved', (tester) async {
    final quoteId = await runAsyncAndPump(tester, () async {
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
      MaterialApp(home: EditMilestonesScreen(quoteId: quoteId)),
    );
    await tester.pumpAndSettle();
    await waitForText(tester, 'Quote Total');

    await addMilestone(tester);
    await tester.pumpAndSettle();
    await waitForText(tester, 'Milestone 1');
    expect(find.text('Milestone 1'), findsOneWidget);
  });
}

Future<void> addMilestone(WidgetTester tester) async {
  final button = tester.widget<HMBButtonAdd>(find.byType(HMBButtonAdd));
  expect(button.enabled, isTrue);
  expect(button.onAdd, isNotNull);
  // The async callback includes insertion and redistribution. Wait for that
  // operation rather than guessing how quickly the database will finish.
  await runAsyncAndPump(tester, button.onAdd!);
}
