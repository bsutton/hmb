import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/invoice.dart';
import 'package:hmb/ui/invoicing/quickbooks_export_screen.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);
  testWidgets('export requires customer verification and shows limitations', (
    tester,
  ) async {
    final invoice = Invoice.forInsert(
      jobId: 1,
      dueDate: LocalDate.today(),
      totalAmount: MoneyEx.dollars(110),
      billingContactId: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: QuickBooksExportScreen(invoice: invoice)),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Destination: sandbox company'), findsOneWidget);
    expect(find.textContaining('reconciled separately'), findsOneWidget);
    expect(find.text('Confirm and export'), findsNothing);
    expect(find.text('Check customer'), findsOneWidget);
  });
}
