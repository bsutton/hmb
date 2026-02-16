/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';
import 'invoice/utility.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  group('DaoJob Tests', () {
    test('should create a job and retrieve it', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      final retrievedJob = await DaoJob().getById(job.id);
      expect(retrievedJob, isNotNull);
      expect(retrievedJob?.id, equals(job.id));
      expect(retrievedJob?.billingType, equals(BillingType.timeAndMaterial));
      expect(
        retrievedJob?.hourlyRate,
        equals(Money.fromInt(5000, isoCode: 'AUD')),
      );
      expect(
        retrievedJob?.bookingFee,
        equals(Money.fromInt(10000, isoCode: 'AUD')),
      );
    });

    test('should update a job and verify the changes', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      job.hourlyRate = Money.fromInt(7000, isoCode: 'AUD');
      await DaoJob().update(job);

      final retrievedJob = await DaoJob().getById(job.id);
      expect(
        retrievedJob?.hourlyRate,
        equals(Money.fromInt(7000, isoCode: 'AUD')),
      );
    });

    test('should delete a job and verify it is removed', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      await DaoJob().delete(job.id);

      final retrievedJob = await DaoJob().getById(job.id);
      expect(retrievedJob, isNull);
    });

    test('should get all jobs', () async {
      final now = DateTime.now();
      await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );
      await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(7000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(15000, isoCode: 'AUD'),
      );

      final jobs = await DaoJob().getAll();
      expect(jobs.length, equals(2));
    });

    test('should find jobs by name', () async {
      final now = DateTime.now();
      await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );
      await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(7000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(15000, isoCode: 'AUD'),
        summary: 'Special Job',
      );

      final jobs = await DaoJob().getByFilter('Special Job');
      expect(jobs.length, equals(1));
      expect(jobs.first.summary, equals('Special Job'));
    });

    test('should get active jobs', () async {
      final now = DateTime.now();
      final activeJob = await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
        summary: 'Active Job Test',
      );
      final inactiveJob = await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(7000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(15000, isoCode: 'AUD'),
        summary: 'Inactive Job Test',
      );

      inactiveJob.status = JobStatus.rejected;
      await DaoJob().update(inactiveJob);

      final activeJobs = await DaoJob().getActiveJobs('Active Job Test');
      expect(activeJobs.length, equals(1));
      expect(activeJobs.first.id, equals(activeJob.id));
    });

    test('should set job as inactive', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      job.lastActive = false;
      await DaoJob().update(job);

      final retrievedJob = await DaoJob().getById(job.id);
      expect(retrievedJob?.lastActive, isFalse);
    });

    test('finalising a job closes linked todos', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      await DaoToDo().insert(
        ToDo.forInsert(
          title: 'Follow up on materials',
          parentType: ToDoParentType.job,
          parentId: job.id,
        ),
      );
      expect((await DaoToDo().getByJob(job.id)).length, 1);

      job.status = JobStatus.completed;
      await DaoJob().update(job);

      final todos = await DaoToDo().getByJob(job.id);
      expect(todos.length, 1);
      expect(todos.first.status, ToDoStatus.done);
    });

    test(
      'rejecting a job rejects all non-rejected quotes for that job',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.fixedPrice,
          hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
          bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
        );

        final quote1Id = await DaoQuote().insert(
          Quote.forInsert(
            jobId: job.id,
            summary: 'Quote 1',
            description: 'Quote 1 description',
            totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
            state: QuoteState.sent,
          ),
        );
        final quote2Id = await DaoQuote().insert(
          Quote.forInsert(
            jobId: job.id,
            summary: 'Quote 2',
            description: 'Quote 2 description',
            totalAmount: Money.fromInt(15000, isoCode: 'AUD'),
            state: QuoteState.approved,
          ),
        );

        job.status = JobStatus.rejected;
        await DaoJob().update(job);

        final quote1 = await DaoQuote().getById(quote1Id);
        final quote2 = await DaoQuote().getById(quote2Id);

        expect(quote1?.state, QuoteState.rejected);
        expect(quote2?.state, QuoteState.rejected);
      },
    );


    test('copy job and move task completes and re-links moved task', () async {
      final now = DateTime.now();
      final sourceJob = await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
        summary: 'Source Job',
      );

      final task = await createTask(sourceJob, 'Move Me');

      final copied = await DaoJob()
          .copyJobAndMoveTasks(
            job: sourceJob,
            tasksToMove: [task],
            summary: 'Copied Job',
          )
          .timeout(const Duration(seconds: 5));

      expect(copied.id, isNot(equals(sourceJob.id)));
      expect(copied.summary, equals('Copied Job'));

      final movedTask = await DaoTask().getById(task.id);
      expect(movedTask, isNotNull);
      expect(movedTask!.jobId, equals(copied.id));

    test('readyToBeInvoiced includes job with unsent invoice', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      await DaoInvoice().insert(
        Invoice.forInsert(
          jobId: job.id,
          dueDate: LocalDate.today(),
          totalAmount: Money.fromInt(5000, isoCode: 'AUD'),
          billingContactId: 1,
        ),
      );

      final ready = await DaoJob().readyToBeInvoiced(null);
      expect(ready.any((j) => j.id == job.id), isTrue);
    });

    test('readyToBeInvoiced excludes jobs with only sent invoices', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      await DaoInvoice().insert(
        Invoice.forInsert(
          jobId: job.id,
          dueDate: LocalDate.today(),
          totalAmount: Money.fromInt(5000, isoCode: 'AUD'),
          billingContactId: 1,
          sent: true,
        ),
      );

      final ready = await DaoJob().readyToBeInvoiced(null);
      expect(ready.any((j) => j.id == job.id), isFalse);

    });
  });
}
