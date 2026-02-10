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

  testWidgets('reject dialog can reject quote and job', (tester) async {
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

    final quote = (await DaoQuote().getById(quoteId))!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteCard(
            quote: quote,
            onStateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rejected'));
    await tester.pumpAndSettle();

    expect(find.text('Reject Quote'), findsOneWidget);
    expect(find.text('Quote Only'), findsOneWidget);
    expect(find.text('Quote + Job'), findsOneWidget);

    await tester.tap(find.text('Quote + Job'));
    await tester.pumpAndSettle();

    final updatedQuote = await DaoQuote().getById(quoteId);
    final updatedJob = await DaoJob().getById(job.id);

    expect(updatedQuote?.state, QuoteState.rejected);
    expect(updatedJob?.status, JobStatus.rejected);
  });

  testWidgets('unapprove button rolls approved quote back to sent', (tester) async {
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

    final quote = (await DaoQuote().getById(quoteId))!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteCard(
            quote: quote,
            onStateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unapprove'));
    await tester.pumpAndSettle();

    final updatedQuote = await DaoQuote().getById(quoteId);
    expect(updatedQuote?.state, QuoteState.sent);
  });
}
