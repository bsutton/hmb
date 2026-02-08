import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/milestone/list_milestone_screen.dart';
import 'package:money2/money2.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('summary counts exclude voided milestones', (tester) async {
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

    await tester.pumpWidget(
      const MaterialApp(home: ListMilestoneScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Milestones: 1'), findsOneWidget);
    expect(find.text('Voided Milestones: 1'), findsOneWidget);
    expect(find.text('Invoiced Milestones: 0'), findsOneWidget);
    expect(
      find.text(
        'Total Value: ${Money.fromInt(10000, isoCode: 'AUD')}',
      ),
      findsOneWidget,
    );
  });
}
