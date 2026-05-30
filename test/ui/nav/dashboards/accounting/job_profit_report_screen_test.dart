@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/nav/dashboards/accounting/job_profit_report_screen.dart';

import '../../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('job selector does not show add button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JobProfitReportScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('job selector dialog does not show add button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JobProfitReportScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a Job'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.add), findsNothing);
  });
}
