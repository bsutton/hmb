@Tags(['flutter'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/billing_attention_cache.dart';
import 'package:hmb/dao/job_billing_readiness_service.dart';
import 'package:hmb/ui/nav/dashboards/accounting/billing_attention_count.dart';
import 'package:material_ui/material_ui.dart';

void main() {
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
    expect(find.text('Updating billing…'), findsOneWidget);
    expect(find.text('Jobs to bill: —'), findsOneWidget);
    await tester.tap(find.text('Jobs'));
    expect(taps, 1);
    pending.completeError(StateError('Unavailable'));
    await tester.pump();
    expect(
      find.text('Billing count unavailable — reopen to retry'),
      findsOneWidget,
    );
    expect(find.text('Jobs to bill: 0'), findsNothing);
    await tester.tap(find.text('Jobs'));
    expect(taps, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
