import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_customer.dart';
import 'package:hmb/entity/customer.dart';
import 'package:hmb/ui/crud/customer/customer_creator.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  testWidgets('duplicate customer keeps the form and entered details', (
    tester,
  ) async {
    await tester.runAsync(
      () => DaoCustomer().insert(
        Customer.forInsert(
          name: 'Existing customer',
          description: '',
          disbarred: false,
          customerType: CustomerType.residential,
          hourlyRate: MoneyEx.zero,
          billingContactId: null,
        ),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ToastificationWrapper(
        child: MaterialApp(home: Scaffold(body: CustomerCreator())),
      ),
    );
    await tester.pumpAndSettle();

    Finder field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    await tester.enterText(field('Customer Name'), 'Existing customer');
    await tester.enterText(field('First Name'), 'Keep first name');
    await tester.enterText(field('Surname'), 'Keep surname');
    await tester.enterText(field('Address Line 1'), '12 Test Street');
    await tester.runAsync(() async {
      await tester.tap(find.text('Create Customer').last);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.byType(CustomerCreator), findsOneWidget);
    expect(find.text('Keep first name'), findsOneWidget);
    expect(find.text('Keep surname'), findsOneWidget);
    expect(find.text('12 Test Street'), findsOneWidget);
    expect(find.textContaining('Use the existing customer'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    toastification.dismissAll();
    await tester.pumpAndSettle();
  });
}
