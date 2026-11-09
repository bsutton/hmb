import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/task_items/list_packing_screen.dart';
import 'package:hmb/ui/task_items/list_shopping_screen.dart';
import 'package:hmb/ui/task_items/purchased_item_card.dart';
import 'package:hmb/ui/task_items/return_item_card.dart';
import 'package:hmb/ui/task_items/shopping_item_card.dart';
import 'package:hmb/ui/task_items/to_purchase_item_card.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';

import '../../dao/invoice/utility.dart' show createTask, insertMaterialItem;
import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  for (final (units, amount, expected) in [
    (Units.m, '2.4', 'Length: 2.400 m'),
    (Units.liters, '4', 'Volume: 4.000 litres'),
    (Units.ft, '8', 'Length: 8.000 ft'),
  ]) {
    testWidgets('saved $units measurement is visible on every shopping card', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late TaskItemContext itemContext;
      late CustomerAndJob details;
      await tester.runAsync(() async {
        final job = await createJobWithCustomer(
          billingType: BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.zero,
        );
        final task = await createTask(job, 'Shopping task');
        final item = await insertMaterialItem(
          task,
          itemType: TaskItemType.materialsBuy,
          description: 'Measured material',
          actualQuantity: Fixed.fromNum(3),
          actualUnitCost: MoneyEx.dollars(10),
        );
        await DaoTaskItem().update(
          item.copyWith(
            units: units,
            measurementType: units == Units.liters
                ? MeasurementType.volume
                : MeasurementType.length,
            dimension1: Fixed.parse(amount, decimalDigits: 3),
            dimension2: Fixed.zero,
            dimension3: Fixed.zero,
          ),
        );
        itemContext = TaskItemContext(
          task: task,
          taskItem: (await DaoTaskItem().getById(item.id))!,
          billingType: job.billingType,
          wasReturned: false,
        );
        details = await CustomerAndJob.fetch(itemContext);
      });
      for (final state in ['purchase', 'purchased', 'return']) {
        ShoppingItemCard card() => switch (state) {
          'purchase' => ToPurchaseItemCard(
            itemContext: itemContext,
            details: details,
            onReload: () async {},
          ),
          'purchased' => PurchasedItemCard(
            itemContext: itemContext,
            details: details,
            onReload: () async {},
          ),
          _ => ReturnItemCard(
            itemContext: itemContext,
            details: details,
            onReload: () async {},
          ),
        };
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(body: SingleChildScrollView(child: card())),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        expect(find.text('Quantity: 3'), findsOneWidget);
        final measurement = tester.widget<Text>(find.text(expected));
        expect(measurement.maxLines, isNull);
        expect(measurement.overflow, isNot(TextOverflow.ellipsis));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('litre names support both stored spellings', () {
    expect(Units.fromName('liters'), Units.liters);
    expect(Units.fromName(Units.liters.name), Units.liters);
  });
}
