import 'package:deferred_state/deferred_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/invoice.dart';
import 'package:hmb/ui/invoicing/quickbooks_export_screen.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../database/management/db_utility_test_helper.dart';
import 'ui_test_helpers.dart';

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
    final state = tester.state<DeferredState<QuickBooksExportScreen>>(
      find.byType(QuickBooksExportScreen),
    );
    await runAsyncAndPump(tester, () => state.initialised);
    expect(find.text('Destination: sandbox company'), findsOneWidget);
    expect(find.textContaining('reconciled separately'), findsOneWidget);
    expect(find.text('Confirm and export'), findsNothing);
    expect(find.text('Check customer'), findsOneWidget);
  });
}
