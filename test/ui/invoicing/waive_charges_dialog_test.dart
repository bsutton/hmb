import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/billing_service.dart';
import 'package:hmb/ui/invoicing/waive_charges_dialog.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('waiving shows selected charge and requires an explicit reason', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => WaiveChargesDialog(
                    charges: [
                      BillingCandidate(
                        kind: 'time',
                        sourceId: 1,
                        description: 'Additional tile',
                        group: 'Labour',
                        amount: MoneyEx.dollars(66),
                        version: 'test',
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text(r'Additional tile — $66.00'), findsOneWidget);
    await tester.tap(find.text('Waive charges'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(
      find.text('Enter a reason for waiving these charges.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), 'Too late to bill');
    await tester.tap(find.text('Waive charges'));
    await tester.pumpAndSettle();
    expect(result, 'Too late to bill');
  });
}
