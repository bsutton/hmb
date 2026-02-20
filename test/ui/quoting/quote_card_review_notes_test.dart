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

  Future<Quote> createQuote(WidgetTester tester, QuoteState state) async {
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
          state: state,
        ),
      );
      return DaoQuote().getById(quoteId);
    });

    return quote!;
  }

  testWidgets('unapprove replaces approved when quote is approved', (
    tester,
  ) async {
    final quote = await createQuote(tester, QuoteState.approved);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteCard(quote: quote, onStateChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await waitForText(tester, 'Unapprove');

    expect(find.widgetWithText(ElevatedButton, 'Unapprove'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Approved'), findsNothing);
  });

  testWidgets('withdrawn appears only after quote is sent', (tester) async {
    late final Quote sentQuote;
    late final Quote reviewingQuote;

    sentQuote = await createQuote(tester, QuoteState.sent);
    reviewingQuote = await createQuote(tester, QuoteState.reviewing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              QuoteCard(quote: sentQuote, onStateChanged: (_) {}),
              QuoteCard(quote: reviewingQuote, onStateChanged: (_) {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await waitForText(tester, 'Withdraw');

    // Only the sent quote should show the Withdrawn action.
    expect(find.text('Withdraw'), findsOneWidget);
  });
}
