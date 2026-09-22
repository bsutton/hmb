import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/time_entry_billing_fields.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('nonbillable invoice visibility is explicit and lockable', (
    tester,
  ) async {
    var billable = true;
    var show = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) => TimeEntryBillingFields(
              billable: billable,
              showOnInvoice: show,
              locked: false,
              onBillableChanged: (value) => setState(() => billable = value),
              onShowOnInvoiceChanged: (value) => setState(() => show = value),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Show on invoice'), findsNothing);
    await tester.tap(find.byTooltip('Charge for this time'));
    await tester.pump();
    expect(billable, isFalse);
    expect(find.text('Show on invoice'), findsOneWidget);
    await tester.tap(
      find.byTooltip('Include a no-charge line when invoicing this task'),
    );
    await tester.pump();
    expect(show, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeEntryBillingFields(
            billable: false,
            showOnInvoice: true,
            locked: true,
            onBillableChanged: (_) => fail('Locked'),
            onShowOnInvoiceChanged: (_) => fail('Locked'),
          ),
        ),
      ),
    );
    expect(find.byType(IconButton), findsNothing);
    expect(find.textContaining('locked'), findsOneWidget);
  });
}
