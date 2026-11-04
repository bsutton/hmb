import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('same as job task follows a later billing type change', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.dollars(88),
    );
    final task = Task.forInsert(
      jobId: job.id,
      name: 'Inherited billing',
      description: '',
      status: TaskStatus.awaitingApproval,
    );
    await DaoTask().insert(task);
    expect((await DaoTask().getById(task.id))!.billingType, isNull);

    await DaoJob().update(job.copyWith(billingType: BillingType.fixedPrice));
    final inherited = (await DaoTask().getById(task.id))!;
    expect(inherited.billingType, isNull);
    expect(await DaoTask().getBillingType(inherited), BillingType.fixedPrice);

    await DaoTask().update(inherited.copyWith(name: 'Updated task'));
    expect((await DaoTask().getById(task.id))!.billingType, isNull);
  });

  test('worked inherited task keeps its original billing type', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.dollars(88),
    );
    final task = Task.forInsert(
      jobId: job.id,
      name: 'Worked task',
      description: '',
      status: TaskStatus.inProgress,
    );
    await DaoTask().insert(task);
    await DaoTimeEntry().insert(
      TimeEntry.forInsert(
        taskId: task.id,
        startTime: DateTime(2026, 11, 3, 9),
        endTime: DateTime(2026, 11, 3, 10),
      ),
    );

    await DaoJob().update(job.copyWith(billingType: BillingType.fixedPrice));
    final frozen = (await DaoTask().getById(task.id))!;
    expect(frozen.billingType, BillingType.timeAndMaterial);
    expect(await DaoTask().getBillingType(frozen), BillingType.timeAndMaterial);
  });

  test(
    'task estimateComplete defaults to false and persists updates',
    () async {
      final customer = Customer.forInsert(
        name: 'Estimate Customer',
        description: '',
        disbarred: false,
        customerType: CustomerType.residential,
        hourlyRate: MoneyEx.zero,
        billingContactId: null,
      );
      await DaoCustomer().insert(customer);

      final job = Job.forInsert(
        customerId: customer.id,
        summary: 'Estimate Job',
        description: '',
        siteId: null,
        contactId: null,
        billingContactId: null,
        status: JobStatus.inProgress,
        hourlyRate: MoneyEx.zero,
        bookingFee: MoneyEx.zero,
      );
      await DaoJob().insert(job);

      final task = Task.forInsert(
        jobId: job.id,
        name: 'Estimate Task',
        description: '',
        status: TaskStatus.awaitingApproval,
      );
      await DaoTask().insert(task);

      final inserted = (await DaoTask().getById(task.id))!;
      expect(inserted.estimateComplete, isFalse);
      expect(inserted.status, TaskStatus.awaitingApproval);

      await DaoTask().update(inserted.copyWith(estimateComplete: true));

      final updated = (await DaoTask().getById(task.id))!;
      expect(updated.estimateComplete, isTrue);
      expect(updated.status, TaskStatus.awaitingApproval);
    },
  );

  test('job estimates exclude completed tasks', () async {
    final customer = Customer.forInsert(
      name: 'Estimate Customer',
      description: '',
      disbarred: false,
      customerType: CustomerType.residential,
      hourlyRate: MoneyEx.zero,
      billingContactId: null,
    );
    await DaoCustomer().insert(customer);

    final job = Job.forInsert(
      customerId: customer.id,
      summary: 'Estimate Job',
      description: '',
      siteId: null,
      contactId: null,
      billingContactId: null,
      status: JobStatus.inProgress,
      hourlyRate: MoneyEx.zero,
      bookingFee: MoneyEx.zero,
    );
    await DaoJob().insert(job);

    final activeTask = await _insertEstimatedTask(
      job: job,
      name: 'Active estimate task',
      status: TaskStatus.awaitingApproval,
      unitCost: MoneyEx.fromInt(1000),
    );
    await _insertEstimatedTask(
      job: job,
      name: 'Completed estimate task',
      status: TaskStatus.completed,
      unitCost: MoneyEx.fromInt(2000),
    );

    final estimates = await DaoTask().getEstimatesForJob(job);

    expect(estimates.map((estimate) => estimate.task.id), [activeTask.id]);
  });

  test('open task lookup excludes completed and cancelled tasks', () async {
    final customer = Customer.forInsert(
      name: 'Packing Customer',
      description: '',
      disbarred: false,
      customerType: CustomerType.residential,
      hourlyRate: MoneyEx.zero,
      billingContactId: null,
    );
    await DaoCustomer().insert(customer);
    final job = Job.forInsert(
      customerId: customer.id,
      summary: 'Packing Job',
      description: '',
      siteId: null,
      contactId: null,
      billingContactId: null,
      status: JobStatus.inProgress,
      hourlyRate: MoneyEx.zero,
      bookingFee: MoneyEx.zero,
    );
    await DaoJob().insert(job);

    Future<Task> insertTask(String name, TaskStatus status) async {
      final task = Task.forInsert(
        jobId: job.id,
        name: name,
        description: '',
        status: status,
      );
      await DaoTask().insert(task);
      return task;
    }

    final open = await insertTask('Open task', TaskStatus.inProgress);
    final onHold = await insertTask('Paused task', TaskStatus.onHold);
    await insertTask('Completed task', TaskStatus.completed);
    await insertTask('Cancelled task', TaskStatus.cancelled);

    final tasks = await DaoTask().getOpenTasksByJob(job.id);

    expect(tasks.map((task) => task.id), containsAll([open.id, onHold.id]));
    expect(tasks, hasLength(2));
    expect(
      (await DaoTask().getOpenTasksByJob(
        job.id,
        'Open',
      )).map((task) => task.id),
      [open.id],
    );
  });
}

Future<Task> _insertEstimatedTask({
  required Job job,
  required String name,
  required TaskStatus status,
  required Money unitCost,
}) async {
  final task = Task.forInsert(
    jobId: job.id,
    name: name,
    description: '',
    status: status,
  );
  await DaoTask().insert(task);

  final item = TaskItem.forInsert(
    taskId: task.id,
    description: '$name item',
    itemType: TaskItemType.materialsBuy,
    margin: Percentage.zero,
    measurementType: MeasurementType.length,
    dimension1: Fixed.zero,
    dimension2: Fixed.zero,
    dimension3: Fixed.zero,
    units: Units.defaultUnits,
    url: '',
    purpose: '',
    labourEntryMode: LabourEntryMode.hours,
    chargeMode: ChargeMode.calculated,
    estimatedPrice: MaterialPrice.items(
      quantity: Fixed.one,
      unitCost: unitCost,
    ),
  );
  await DaoTaskItem().insert(item);
  return task;
}
