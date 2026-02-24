import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
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

  test('getSupplierNamesByTaskId returns distinct ordered names', () async {
    final task = await _insertTask();

    final supplierA = await _insertSupplier(name: 'Beta Plumbing');
    final supplierB = await _insertSupplier(name: 'Alpha Electrical');
    final contact = await _insertContact();

    final assignment1 = WorkAssignment.forInsert(
      jobId: task.jobId,
      supplierId: supplierA.id,
      contactId: contact.id,
    );
    await DaoWorkAssignment().insert(assignment1);
    final assignment2 = WorkAssignment.forInsert(
      jobId: task.jobId,
      supplierId: supplierB.id,
      contactId: contact.id,
    );
    await DaoWorkAssignment().insert(assignment2);
    final assignment3 = WorkAssignment.forInsert(
      jobId: task.jobId,
      supplierId: supplierA.id,
      contactId: contact.id,
    );
    await DaoWorkAssignment().insert(assignment3);

    await DaoWorkAssignmentTask().insert(
      WorkAssignmentTask.forInsert(
        assignmentId: assignment1.id,
        taskId: task.id,
      ),
    );
    await DaoWorkAssignmentTask().insert(
      WorkAssignmentTask.forInsert(
        assignmentId: assignment2.id,
        taskId: task.id,
      ),
    );
    await DaoWorkAssignmentTask().insert(
      WorkAssignmentTask.forInsert(
        assignmentId: assignment3.id,
        taskId: task.id,
      ),
    );

    final supplierNames = await DaoWorkAssignmentTask()
        .getSupplierNamesByTaskId(task.id);

    expect(supplierNames, ['Alpha Electrical', 'Beta Plumbing']);
  });
}

Future<Task> _insertTask() async {
  final job = await createJobWithCustomer(
    billingType: BillingType.timeAndMaterial,
    hourlyRate: MoneyEx.zero,
    summary: 'Assignment supplier names test',
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

Future<Supplier> _insertSupplier({required String name}) async {
  final supplier = Supplier.forInsert(
    name: name,
    businessNumber: '',
    description: '',
    bsb: '',
    accountNumber: '',
    service: '',
  );
  await DaoSupplier().insert(supplier);
  return supplier;
}

Future<Contact> _insertContact() async {
  final contact = Contact.forInsert(
    firstName: 'Subby',
    surname: 'Contact',
    mobileNumber: '0400000000',
    landLine: '',
    officeNumber: '',
    emailAddress: 'subby@example.com',
  );
  await DaoContact().insert(contact);
  return contact;
}
