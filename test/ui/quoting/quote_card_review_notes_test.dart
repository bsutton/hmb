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

  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  Future<Quote> createQuote(QuoteState state) async {
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
    return (await DaoQuote().getById(quoteId))!;
  }

  testWidgets('unapprove replaces approved when quote is approved', (
    tester,
  ) async {
    final quote = await createQuote(QuoteState.approved);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteCard(quote: quote, onStateChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unapprove'), findsOneWidget);
    expect(find.text('Approved'), findsNothing);
  });

  testWidgets('withdrawn appears only after quote is sent', (tester) async {
    final sentQuote = await createQuote(QuoteState.sent);
    final reviewingQuote = await createQuote(QuoteState.reviewing);

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

    // Only the sent quote should show the Withdrawn action.
    expect(find.text('Withdrawn'), findsOneWidget);
  });
}
