@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/accounting_report_service.dart';
import 'package:hmb/ui/nav/dashboards/accounting/accounting_period_selector.dart';

void main() {
  testWidgets('period selector exposes report period controls', (tester) async {
    AccountingPeriod? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountingPeriodSelector(
            initialPeriod: AccountingPeriod.month(2026, 5),
            onChanged: (period) => selected = period,
          ),
        ),
      ),
    );

    expect(find.text('Month'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(selected?.startInclusive, DateTime(2026, 6));
    expect(selected?.endExclusive, DateTime(2026, 7));
  });
}
