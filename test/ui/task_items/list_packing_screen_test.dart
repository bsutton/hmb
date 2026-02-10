import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/ui/task_items/list_packing_screen.dart';
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

  testWidgets('can move packing item to shopping list', (tester) async {
    final taskItemId = await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
        summary: 'Packing Move Job',
      );
      job.status = JobStatus.scheduled;
      await DaoJob().update(job);

      final task = Task.forInsert(
        jobId: job.id,
        name: 'Packing Task',
        description: 'Task with stock item',
        status: TaskStatus.approved,
      );
      final taskId = await DaoTask().insert(task);

      return DaoTaskItem().insert(
        TaskItem.forInsert(
          taskId: taskId,
          description: 'Stock material item',
          purpose: '',
          itemType: TaskItemType.materialsStock,
          margin: Percentage.zero,
          measurementType: MeasurementType.length,
          dimension1: Fixed.fromNum(1, decimalDigits: 3),
          dimension2: Fixed.fromNum(1, decimalDigits: 3),
          dimension3: Fixed.fromNum(1, decimalDigits: 3),
          units: Units.m,
          url: '',
          labourEntryMode: LabourEntryMode.hours,
          chargeMode: ChargeMode.calculated,
          estimatedMaterialUnitCost: Money.fromInt(1000, isoCode: 'AUD'),
          estimatedMaterialQuantity: Fixed.fromNum(1, decimalDigits: 3),
        ),
      );
    });

    await tester.pumpWidget(const MaterialApp(home: PackingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Stock material item'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.shopping_cart).first);
    await tester.pumpAndSettle();

    expect(find.text('Move to Shopping List'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    final updated = await tester.runAsync(
      () => DaoTaskItem().getById(taskItemId),
    );
    expect(updated, isNotNull);
    expect(updated!.itemType, TaskItemType.materialsBuy);
  });
}
