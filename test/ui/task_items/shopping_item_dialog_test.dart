@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/ui/task_items/list_packing_screen.dart';
import 'package:hmb/ui/task_items/shopping_item_dialog.dart';
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

  testWidgets('shopping item edit saves packet details as unit values', (
    tester,
  ) async {
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
        estimatedMaterialUnitCost: Money.fromInt(100, isoCode: 'AUD'),
        estimatedMaterialQuantity: Fixed.fromNum(1, decimalDigits: 3),
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
    await tester.tap(find.text('Enter Packet Details'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Cost per Packet'),
      '12.00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Items per Packet'),
      '6',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Packets Purchased'),
      '3',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final reloaded = await DaoTaskItem().getById(item.id);

      expect(
        reloaded!.actualMaterialUnitCost,
        Money.fromInt(200, isoCode: 'AUD'),
      );
      expect(
        reloaded.actualMaterialQuantity,
        Fixed.fromNum(18, decimalDigits: 3),
      );
    });
  });
}
