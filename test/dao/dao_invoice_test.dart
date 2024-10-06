import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/_index.g.dart';
import 'package:hmb/entity/_index.g.dart';
import 'package:hmb/util/measurement_type.dart';
import 'package:hmb/util/money_ex.dart';
import 'package:hmb/util/units.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });
  group('Invoice Creation - Time and Materials Billing', () {
    test('''
should create an invoice for time and materials job with correct rates and mark items as billed''',
        () async {
      // Insert a job with time and materials billing type
      final job = Job.forInsert(
        customerId: 1, // Assuming a customer ID
        summary: 'Time and Materials Job',
        description: 'This is a T&M job',
        startDate: DateTime.now(),
        siteId: 1, // Assuming a site ID
        contactId: 1, // Assuming a contact ID
        jobStatusId: 1, // Assuming job status ID
        hourlyRate: MoneyEx.fromInt(5000), // $50 per hour
        callOutFee: MoneyEx.fromInt(1000), // $10 callout fee
      );
      final jobId = await DaoJob().insert(job);

      // Insert task for the job
      final task = Task.forInsert(
        jobId: jobId,
        name: 'Task 1',
        description: 'First task for T&M',
        taskStatusId: 1, // Assuming task status ID
      );
      final taskId = await DaoTask().insert(task);

      // Insert a time entry for the task
      final timeEntry = TimeEntry.forInsert(
          taskId: taskId,
          startTime: DateTime.now().subtract(const Duration(hours: 2)),
          note: 'Worked on Task 1');
      await DaoTimeEntry().insert(timeEntry);
      timeEntry.copyWith(
          endTime: timeEntry.startTime.add(const Duration(minutes: 60)));
      await DaoTimeEntry().update(timeEntry);
      final materialsBuy = await DaoCheckListItemType().getMaterialsBuy();

      final checkList = await DaoCheckList().getByTask(task.id);

      final completedMaterialItem = CheckListItem.forInsert(
        checkListId: checkList!.id, // Assuming a check list ID
        description: 'Completed Material Item',
        itemTypeId: materialsBuy.id,
        estimatedMaterialUnitCost: MoneyEx.fromInt(500), // $5/unit
        estimatedMaterialQuantity: Fixed.fromNum(10, scale: 3), // 10 units
        estimatedLabourHours: Fixed.fromNum(2, scale: 3), // 2 hours of labour
        estimatedLabourCost: MoneyEx.fromInt(5000), // $50 labour cost
        charge: MoneyEx.fromInt(5500), // $55 charge
        margin: Percentage.fromNum(0.1, scale: 3), // 10% margin
        completed: true,
        measurementType: MeasurementType.length,
        dimension1: Fixed.fromNum(1, scale: 3),
        dimension2: Fixed.fromNum(1, scale: 3),
        dimension3: Fixed.fromNum(1, scale: 3),
        units: Units.m,
        url: 'http://example.com/material',
        labourEntryMode: LabourEntryMode.hours,
      );
      await DaoCheckListItem().insert(completedMaterialItem);

      // Create invoice for the job
      final invoice =
          await DaoInvoice().create(job, [taskId], groupByTask: false);

      // Verify that the invoice includes both time entry and material item
      final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
      expect(invoiceLines.length, equals(2));

      // Verify that the time entry and checklist item are marked as billed
      final billedTimeEntry = await DaoTimeEntry().getById(timeEntry.id);
      expect(billedTimeEntry?.billed, isTrue);

      final billedMaterialItem =
          await DaoCheckListItem().getById(completedMaterialItem.id);
      expect(billedMaterialItem?.billed, isTrue);
    });
  });
}
