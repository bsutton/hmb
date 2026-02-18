import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/quoting/quote_card.dart';
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

  testWidgets('reject dialog can reject quote and job', (tester) async {
    final quote = await tester.runAsync(() async {
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
          state: QuoteState.sent,
        ),
      );

      return (await DaoQuote().getById(quoteId))!;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteCard(quote: quote!, onStateChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await waitForText(tester, 'Rejected');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Rejected'));
    await tester.pumpAndSettle();

    expect(find.text('Reject Quote'), findsOneWidget);
    expect(find.text('Quote Only'), findsOneWidget);
    expect(find.text('Quote + Job'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reject Quote'), findsNothing);
  });

  testWidgets('unapprove button rolls approved quote back to sent', (
    tester,
  ) async {
    final quote = await tester.runAsync(() async {
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
          state: QuoteState.approved,
        ),
      );

      return (await DaoQuote().getById(quoteId))!;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteCard(quote: quote!, onStateChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await waitForText(tester, 'Unapprove');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Unapprove'));
    await tester.pumpAndSettle();

    final updatedQuote = await tester.runAsync(
      () => DaoQuote().getById(quote.id),
    );
    expect(updatedQuote?.state, QuoteState.sent);
  });

  testWidgets('withdrawn button marks quote withdrawn', (tester) async {
    final quote = await tester.runAsync(() async {
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
          state: QuoteState.sent,
        ),
      );

      return (await DaoQuote().getById(quoteId))!;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteCard(quote: quote!, onStateChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await waitForText(tester, 'Withdrawn');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Withdrawn'));
    await tester.pumpAndSettle();

    expect(find.text('Withdraw Quote'), findsOneWidget);
    expect(find.text('Withdraw'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Withdraw Quote'), findsNothing);
  });
}
