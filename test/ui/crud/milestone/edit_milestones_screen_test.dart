import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/milestone/edit_milestone_payment.dart';
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

  testWidgets('add disabled before quote approval', (tester) async {
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
    final iconButton = tester.widget<IconButton>(iconButtonFinder.first);
    expect(iconButton.onPressed, isNull);
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
