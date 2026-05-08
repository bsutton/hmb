import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
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
}
