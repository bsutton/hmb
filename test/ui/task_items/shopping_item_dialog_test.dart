@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/ui/task_items/list_packing_screen.dart';
import 'package:hmb/ui/task_items/material_price_editor.dart';
import 'package:hmb/ui/task_items/shopping_item_dialog.dart';
import 'package:hmb/ui/widgets/hmb_button.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:money2/money2.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('package editor preserves its draft across mode changes', () {
    final controller = MaterialPriceEditingController(
      price: MaterialPrice.packages(
        packageCount: Fixed.parse('3'),
        packageCost: Money.fromInt(600, isoCode: 'AUD'),
        itemsPerPackage: Fixed.parse('2'),
      ),
    );
    addTearDown(controller.dispose);

    expect(controller.quantity.text, '3');
    expect(controller.itemsPerPackage.text, '2');

    controller.changeMode(MaterialPriceEntryMode.items);
    expect(controller.quantity.text, '6');
    expect(controller.value?.unitCost, Money.fromInt(300, isoCode: 'AUD'));

    controller.changeMode(MaterialPriceEntryMode.packages);
    expect(controller.quantity.text, '3');
    expect(controller.itemsPerPackage.text, '2');
    expect(controller.value?.unitCost, Money.fromInt(600, isoCode: 'AUD'));
  });

  test('first visit to package mode derives an equivalent price', () {
    final controller = MaterialPriceEditingController(
      price: MaterialPrice.items(
        quantity: Fixed.parse('6'),
        unitCost: Money.fromInt(300, isoCode: 'AUD'),
      ),
    );
    addTearDown(controller.dispose);

    controller.changeMode(MaterialPriceEntryMode.packages);

    expect(controller.quantity.text, '1');
    expect(controller.itemsPerPackage.text, '6');
    expect(controller.value?.unitCost, Money.fromInt(1800, isoCode: 'AUD'));

    controller.changeMode(MaterialPriceEntryMode.items);
    expect(controller.quantity.text, '6');
    expect(controller.value?.unitCost, Money.fromInt(300, isoCode: 'AUD'));
  });

  test('editing one mode invalidates and rederives the other draft', () {
    final controller = MaterialPriceEditingController(
      price: MaterialPrice.packages(
        packageCount: Fixed.parse('3'),
        packageCost: Money.fromInt(600, isoCode: 'AUD'),
        itemsPerPackage: Fixed.parse('2'),
      ),
    );
    addTearDown(controller.dispose);

    controller
      ..changeMode(MaterialPriceEntryMode.items)
      ..quantity.text = '8'
      ..markCurrentModeEdited()
      ..changeMode(MaterialPriceEntryMode.packages);

    expect(controller.quantity.text, '1');
    expect(controller.itemsPerPackage.text, '8');
    expect(controller.value?.unitCost, Money.fromInt(2400, isoCode: 'AUD'));
  });

  testWidgets('shopping item edit preserves package pricing', (tester) async {
    late Task task;
    late TaskItem item;

    await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
        summary: 'Shopping Packet Job',
      );
      job.status = JobStatus.scheduled;
      await DaoJob().update(job);

      task = Task.forInsert(
        jobId: job.id,
        name: 'Shopping Packet Task',
        description: 'Task with packet shopping item',
        status: TaskStatus.approved,
      );
      await DaoTask().insert(task);

      item = TaskItem.forInsert(
        taskId: task.id,
        description: 'Packet material item',
        purpose: '',
        itemType: TaskItemType.materialsBuy,
        margin: Percentage.zero,
        measurementType: MeasurementType.length,
        dimension1: Fixed.fromNum(1, decimalDigits: 3),
        dimension2: Fixed.fromNum(1, decimalDigits: 3),
        dimension3: Fixed.fromNum(1, decimalDigits: 3),
        units: Units.m,
        url: '',
        labourEntryMode: LabourEntryMode.hours,
        chargeMode: ChargeMode.calculated,
        estimatedPrice: MaterialPrice.items(
          quantity: Fixed.fromNum(1, decimalDigits: 3),
          unitCost: Money.fromInt(100, isoCode: 'AUD'),
        ),
      );
      await DaoTaskItem().insert(item);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showShoppingItemDialog(
              context,
              TaskItemContext(
                task: task,
                taskItem: item,
                billingType: BillingType.fixedPrice,
                wasReturned: false,
              ),
              () async {},
            ),
            child: const Text('Edit Item'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit Item'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(HMBButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(HMBButton, 'Save'), findsOneWidget);
    await tester.tap(find.text('Packages'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Number of packages'),
          )
          .controller!
          .text,
      '1',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Items per package'),
          )
          .controller!
          .text,
      '1',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Cost per package'),
      '12.00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Items per package'),
      '6',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Number of packages'),
      '3',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Individual items'));
    await tester.tap(find.text('Individual items'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Packages'));
    await tester.tap(find.text('Packages'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Number of packages'),
          )
          .controller!
          .text,
      '3',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Items per package'),
          )
          .controller!
          .text,
      '6',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Cost per package'),
          )
          .controller!
          .text,
      '12.00',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final reloaded = await DaoTaskItem().getById(item.id);

      expect(
        reloaded!.estimatedPrice?.unitCost,
        Money.fromInt(1200, isoCode: 'AUD'),
      );
      expect(
        reloaded.estimatedPrice?.quantity,
        Fixed.fromNum(3, decimalDigits: 3),
      );
      expect(
        reloaded.estimatedPrice?.itemsPerPackage,
        Fixed.fromNum(6, decimalDigits: 3),
      );
      expect(
        reloaded.estimatedPrice?.totalItemQuantity,
        Fixed.fromNum(18, decimalDigits: 3),
      );
      expect(reloaded.actualPrice, isNull);
    });
  });
}
