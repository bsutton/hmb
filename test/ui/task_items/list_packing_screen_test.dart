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

  Future<void> waitForText(
    WidgetTester tester,
    String text, {
    int attempts = 30,
  }) async {
    for (var i = 0; i < attempts; i++) {
      if (find.text(text).evaluate().isNotEmpty) {
        return;
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    throw TestFailure('Timed out waiting for text: $text');
  }

  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('shows move-to-shopping action for packing items', (
    tester,
  ) async {
    await tester.runAsync(() async {
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

      await DaoTaskItem().insert(
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
    await waitForText(tester, 'Stock material item');

    expect(find.text('Stock material item'), findsOneWidget);
    expect(find.byIcon(Icons.shopping_cart), findsWidgets);
  });
}
