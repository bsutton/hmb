import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/exceptions.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('cannot delete task when linked to a work assignment', () async {
    final task = await _insertTask();

    final supplier = Supplier.forInsert(
      name: 'Subby',
      businessNumber: '',
      description: '',
      bsb: '',
      accountNumber: '',
      service: '',
    );
    await DaoSupplier().insert(supplier);

    final contact = Contact.forInsert(
      firstName: 'Work',
      surname: 'Contact',
      mobileNumber: '0400000000',
      landLine: '',
      officeNumber: '',
      emailAddress: 'subby@example.com',
    );
    await DaoContact().insert(contact);

    final assignment = WorkAssignment.forInsert(
      jobId: task.jobId,
      supplierId: supplier.id,
      contactId: contact.id,
    );
    await DaoWorkAssignment().insert(assignment);

    final link = WorkAssignmentTask.forInsert(
      assignmentId: assignment.id,
      taskId: task.id,
    );
    await DaoWorkAssignmentTask().insert(link);

    expect(() => DaoTask().delete(task.id), throwsA(isA<HMBException>()));

    final reloadedTask = await DaoTask().getById(task.id);
    expect(reloadedTask, isNotNull);
    final links = await DaoWorkAssignmentTask().getByTask(task);
    expect(links, hasLength(1));
  });

  test('can delete task when no work assignment links exist', () async {
    final task = await _insertTask();

    await DaoTask().delete(task.id);

    final reloadedTask = await DaoTask().getById(task.id);
    expect(reloadedTask, isNull);
  });

  test('cannot delete task when linked to a task approval', () async {
    final task = await _insertTask();
    final job = await DaoJob().getById(task.jobId);

    final customerContact = await DaoContact().getById(job!.contactId);
    expect(customerContact, isNotNull);

    final approval = TaskApproval.forInsert(
      jobId: job.id,
      contactId: customerContact!.id,
    );
    await DaoTaskApproval().insert(approval);

    final link = TaskApprovalTask.forInsert(
      approvalId: approval.id,
      taskId: task.id,
    );
    await DaoTaskApprovalTask().insert(link);

    expect(() => DaoTask().delete(task.id), throwsA(isA<HMBException>()));

    final reloadedTask = await DaoTask().getById(task.id);
    expect(reloadedTask, isNotNull);
    final links = await DaoTaskApprovalTask().getByTask(task);
    expect(links, hasLength(1));
  });
}

Future<Task> _insertTask() async {
  final job = await createJobWithCustomer(
    billingType: BillingType.timeAndMaterial,
    hourlyRate: MoneyEx.zero,
    summary: 'Task delete test job',
  );

  final task = Task.forInsert(
    jobId: job.id,
    name: 'Assigned Task',
    description: '',
    status: TaskStatus.inProgress,
  );
  await DaoTask().insert(task);
  return task;
}
