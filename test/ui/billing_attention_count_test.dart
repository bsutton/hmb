@Tags(['flutter'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/billing_attention_cache.dart';
import 'package:hmb/dao/job_billing_readiness_service.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/nav/dashboards/accounting/billing_attention_count.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'setup reviews and future payments do not inflate invoice count',
    (tester) async {
      final job = Job.forInsert(
        customerId: null,
        summary: 'Test job',
        description: '',
        siteId: null,
        contactId: null,
        billingContactId: null,
        status: JobStatus.completed,
        hourlyRate: MoneyEx.zero,
        bookingFee: MoneyEx.zero,
      );
      final cache = BillingAttentionCache(
        databaseIdentity: () => null,
        load: () async => [
          for (final code in [
            JobBillingReasonCode.unbilledTimeAndMaterials,
            JobBillingReasonCode.missingApprovedQuote,
            JobBillingReasonCode.futureFixedPayment,
          ])
            JobBillingReadiness(
              job: job,
              reasons: [
                JobBillingReason(
                  code: code,
                  label: code.name,
                  amount: MoneyEx.dollars(100),
                  count: 1,
                  invoiceable: code.invoiceable,
                ),
              ],
            ),
        ],
      );
      addTearDown(cache.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BillingAttentionCount(cache: cache)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Jobs to bill: 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('pending and failed billing scans do not block navigation', (
    tester,
  ) async {
    final pending = Completer<List<JobBillingReadiness>>();
    final cache = BillingAttentionCache(
      load: () => pending.future,
      databaseIdentity: () => null,
    );
    addTearDown(cache.dispose);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BillingAttentionCount(cache: cache),
              TextButton(onPressed: () => taps++, child: const Text('Jobs')),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Updating billing…'), findsNothing);
    expect(find.text('Jobs to bill: …'), findsOneWidget);
    await tester.tap(find.text('Jobs'));
    expect(taps, 1);
    pending.completeError(StateError('Unavailable'));
    await tester.pump();
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('Jobs to bill: 0'), findsNothing);
    await tester.tap(find.text('Jobs'));
    expect(taps, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
