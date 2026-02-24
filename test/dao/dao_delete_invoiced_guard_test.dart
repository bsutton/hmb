import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/util/dart/exceptions.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('cannot delete task when it has invoiced task items', () async {
    final task = await _insertTask();
    final item = TaskItem.forInsert(
      taskId: task.id,
      description: 'Item',
      purpose: '',
      itemType: TaskItemType.materialsBuy,
      estimatedMaterialUnitCost: MoneyEx.fromInt(1000),
      estimatedMaterialQuantity: Fixed.one,
      actualMaterialUnitCost: MoneyEx.fromInt(1000),
      actualMaterialQuantity: Fixed.one,
      billed: true,
      chargeMode: ChargeMode.calculated,
      margin: Percentage.zero,
      measurementType: MeasurementType.length,
      dimension1: Fixed.zero,
      dimension2: Fixed.zero,
      dimension3: Fixed.zero,
      units: Units.m,
      url: '',
      labourEntryMode: LabourEntryMode.hours,
    );
    await DaoTaskItem().insert(item);

    expect(() => DaoTask().delete(task.id), throwsA(isA<HMBException>()));
  });

  test('cannot delete job when it has invoices', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Delete invoiced job',
    );

    final invoice = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(1000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
    );
    await DaoInvoice().insert(invoice);

    expect(() => DaoJob().delete(job.id), throwsA(isA<HMBException>()));
  });

  test('can delete job when it has no invoices', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Delete non-invoiced job',
    );

    await DaoJob().delete(job.id);

    expect(await DaoJob().getById(job.id), isNull);
  });
}

Future<Task> _insertTask() async {
  final job = await createJobWithCustomer(
    billingType: BillingType.timeAndMaterial,
    hourlyRate: MoneyEx.zero,
    summary: 'Invoiced task delete guard',
  );
  final task = Task.forInsert(
    jobId: job.id,
    name: 'Task',
    description: '',
    status: TaskStatus.inProgress,
  );
  await DaoTask().insert(task);
  return task;
}
