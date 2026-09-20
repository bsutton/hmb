import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/billing_attention_cache.dart';
import 'package:hmb/dao/billing_executor.dart';
import 'package:hmb/dao/billing_queue.dart';
import 'package:hmb/dao/billing_worker.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/remaining_billing.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';
import 'invoice/utility.dart' as fixture;

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test(
    'DAO events coalesce; access does not enqueue; rollback is atomic',
    () async {
      final job = await _job();
      await _drain();
      final initial = await _state(job.id);
      expect(initial['billing_required'], 0);
      await DaoJob().recordAccess(job.id);
      expect((await _state(job.id))['revision'], initial['revision']);
      final task = await _task(job);
      final entry = await _entry(task);
      expect((await _state(job.id))['billing_required'], 1);
      await DaoTimeEntry().update(
        entry.copyWith(endTime: DateTime(2025, 1, 1, 11)),
      );
      expect(
        await testDb!.query(
          'job_billing_state',
          where: 'job_id = ?',
          whereArgs: [job.id],
        ),
        hasLength(1),
      );
      final before = await _state(job.id);
      await expectLater(
        testDb!.transaction((txn) async {
          await DaoTimeEntry().update(entry.copyWith(billed: true), txn);
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(await _state(job.id), before);
      expect((await DaoTimeEntry().getById(entry.id))!.billed, isFalse);
    },
  );

  test('a stale check cannot clear a newer billing event', () async {
    final job = await _job();
    final task = await _task(job);
    final gate = Completer<JobBillingReasonCode?>();
    final started = Completer<void>();
    final queue = BillingQueue(
      testDb!,
      check: (id) async {
        if (id == job.id) {
          started.complete();
          return await gate.future;
        }
        return null;
      },
    );
    final running = queue.drain(limit: 10000);
    await started.future;
    await _entry(task);
    gate.complete(null);
    await running;
    final state = await _state(job.id);
    expect(state['billing_required'], 1);
    expect(state['revision'], isNot(state['checked_revision']));
    await _drain();
    expect((await _state(job.id))['billing_required'], 1);
  });

  test(
    'failures persist retry state and do not clear or starve other jobs',
    () async {
      final failed = await _job();
      final other = await _job();
      await BillingQueue(
        testDb!,
        check: (id) async {
          if (id == failed.id) {
            throw StateError('failed');
          }
          return null;
        },
      ).drain(limit: 10000);
      var state = await _state(failed.id);
      expect(state['billing_required'], 1);
      expect(state['attempts'], 1);
      expect(state['failed'], 1);
      expect(state['retry_after'], greaterThan(0));
      expect((await _state(other.id))['billing_required'], 0);
      await _task(failed); // New work resets the backoff.
      state = await _state(failed.id);
      expect(state['retry_after'], 0);
      await _drain();
      expect((await _state(failed.id))['failed'], 0);
    },
  );

  test(
    'moving a task invalidates old and new jobs; deleting time rechecks',
    () async {
      final oldJob = await _job();
      final newJob = await _job();
      final task = await _task(oldJob);
      final entry = await _entry(task);
      await _drain();
      await DaoTask().update(task.copyWith(jobId: newJob.id));
      expect((await _state(oldJob.id))['billing_required'], 1);
      expect((await _state(newJob.id))['billing_required'], 1);
      await _drain();
      expect((await _state(oldJob.id))['billing_required'], 0);
      expect((await _state(newJob.id))['billing_required'], 1);
      await DaoTimeEntry().delete(entry.id);
      await _drain();
      expect((await _state(newJob.id))['billing_required'], 0);
    },
  );

  test(
    'T&M progress invoice clears only its own sources; deletion reopens',
    () async {
      final job = await _job();
      final first = await _task(job);
      final second = await _task(job);
      await _entry(first);
      await _entry(second);
      final contact = Contact.forInsert(
        firstName: 'Test',
        surname: 'Contact',
        mobileNumber: '',
        landLine: '',
        officeNumber: '',
        emailAddress: '',
      );
      await DaoContact().insert(contact);
      final invoice = await createInvoiceForSelectedTasks(
        job,
        contact,
        [first.id],
        groupByTask: true,
        billBookingFee: false,
      );
      await _drain();
      expect((await _state(job.id))['billing_required'], 1);
      await createInvoiceForSelectedTasks(
        job,
        contact,
        [second.id],
        groupByTask: true,
        billBookingFee: false,
      );
      await _drain();
      expect((await _state(job.id))['billing_required'], 0);
      await DaoInvoice().delete(invoice.id);
      await _drain();
      expect((await _state(job.id))['billing_required'], 1);
    },
  );

  test(
    'quote milestones retain progress linkage plus mixed T&M work',
    () async {
      final job = await _job(type: BillingType.fixedPrice);
      final quote = Quote.forInsert(
        jobId: job.id,
        summary: 'Test quote',
        description: '',
        totalAmount: MoneyEx.fromInt(10000),
        state: QuoteState.approved,
      );
      await DaoQuote().insert(quote);
      final first = await _milestone(quote, 1);
      final second = await _milestone(quote, 2);
      final invoice = await _invoice(job);
      first.invoiceId = invoice.id;
      await DaoMilestone().update(first);
      expect(
        await RemainingBilling().check(job.id),
        JobBillingReasonCode.uninvoicedMilestone,
      );
      second.invoiceId = (await _invoice(job)).id;
      await DaoMilestone().update(second);
      expect(await RemainingBilling().check(job.id), isNull);
      final variation = await _task(job, type: BillingType.timeAndMaterial);
      final entry = await _entry(variation);
      expect(
        await RemainingBilling().check(job.id),
        JobBillingReasonCode.unbilledTimeAndMaterials,
      );
      await DaoTimeEntry().update(entry.copyWith(billed: true));
      await _drain();
      expect((await _state(job.id))['billing_required'], 0);
      await DaoMilestone().detachFromInvoice(invoice.id);
      expect((await _state(job.id))['billing_required'], 1);
      expect(
        await RemainingBilling().check(job.id),
        JobBillingReasonCode.uninvoicedMilestone,
      );
    },
  );

  test('task billing override works even on a non-billable job', () async {
    final job = await _job(type: BillingType.nonBillable);
    final task = await _task(job, type: BillingType.timeAndMaterial);
    await _entry(task);
    expect(
      await RemainingBilling().check(job.id),
      JobBillingReasonCode.unbilledTimeAndMaterials,
    );
    await DaoTask().update(task.copyWith(status: TaskStatus.cancelled));
    await _drain();
    expect((await _state(job.id))['billing_required'], 0);
  });

  test(
    'fixed-price task on a T&M job follows task charges, not timesheets',
    () async {
      final job = await _job();
      final task = await _task(job, type: BillingType.fixedPrice);
      await _entry(task);
      expect(await RemainingBilling().check(job.id), isNull);
      final item = await fixture.insertLabourEstimates(
        task,
        MoneyEx.fromInt(5000),
        Fixed.one,
      );
      expect(
        await RemainingBilling().check(job.id),
        JobBillingReasonCode.unbilledTimeAndMaterials,
      );
      await DaoTaskItem().update(item.copyWith(billed: true));
      await _drain();
      expect((await _state(job.id))['billing_required'], 0);
    },
  );

  test(
    'completed materials and returns count, incomplete estimates do not',
    () async {
      final job = await _job();
      final task = await _task(job);
      final item = await fixture.insertMaterialItem(
        task,
        itemType: TaskItemType.materialsBuy,
        actualQuantity: Fixed.one,
        actualUnitCost: MoneyEx.fromInt(1000),
        completed: false,
      );
      expect(await RemainingBilling().check(job.id), isNull);
      await DaoTaskItem().update(item.copyWith(completed: true));
      expect(
        await RemainingBilling().check(job.id),
        JobBillingReasonCode.unbilledTimeAndMaterials,
      );
      await DaoTaskItem().update(item.copyWith(billed: true));
      await fixture.insertMaterialItem(
        task,
        itemType: TaskItemType.materialsBuy,
        actualQuantity: Fixed.one,
        actualUnitCost: MoneyEx.fromInt(1000),
        isReturn: true,
      );
      expect(
        await RemainingBilling().check(job.id),
        JobBillingReasonCode.unbilledTimeAndMaterials,
      );
    },
  );

  test('an existing fee line overrides a stale booking fee flag', () async {
    final job = await _job();
    job.bookingFee = MoneyEx.fromInt(5000);
    await DaoJob().update(job);
    final invoice = await _invoice(job);
    final group = InvoiceLineGroup.forInsert(
      invoiceId: invoice.id,
      name: 'Booking fee',
    );
    await DaoInvoiceLineGroup().insert(group);
    await DaoInvoiceLine().insert(
      InvoiceLine.forInsert(
        invoiceId: invoice.id,
        invoiceLineGroupId: group.id,
        description: 'Booking fee',
        quantity: Fixed.one,
        unitPrice: MoneyEx.fromInt(5000),
        lineTotal: MoneyEx.fromInt(5000),
        fromBookingFee: true,
      ),
    );
    expect(job.bookingFeeInvoiced, isFalse);
    expect(await RemainingBilling().check(job.id), isNull);
    await DaoInvoice().delete(invoice.id);
    expect(
      await RemainingBilling().check(job.id),
      JobBillingReasonCode.unbilledBookingFee,
    );
  });

  test(
    'worker opens its own connection; cache only reads persisted state',
    () async {
      final job = await _job();
      await _entry(await _task(job));
      await BillingWorker.runBatch(testDbPath);
      expect((await _state(job.id))['checked_at'], isNotNull);
      expect(testDb!.isOpen, isTrue);
      // Alter a source outside the DAO to prove the UI does not scan.
      await testDb!.update('time_entry', {'billed': 1});
      final cache = BillingAttentionCache();
      addTearDown(cache.dispose);
      await cache.refresh();
      expect(cache.error, isNull);
      expect(cache.entries!.map((entry) => entry.job.id), contains(job.id));
      // A normal DAO event then reconciles those sources in a fresh isolate.
      await BillingExecutor(testDb!).update(
        'job',
        {'hourly_rate': 11000},
        where: 'id = ?',
        whereArgs: [job.id],
      );
      await BillingWorker.runBatch(testDbPath);
      expect((await _state(job.id))['billing_required'], 0);
    },
  );
}

Future<void> _drain() async {
  await BillingQueue(testDb!).drain(limit: 10000);
}

Future<Map<String, Object?>> _state(int id) async => (await testDb!.query(
  'job_billing_state',
  where: 'job_id = ?',
  whereArgs: [id],
)).single;

Future<Job> _job({BillingType type = BillingType.timeAndMaterial}) async {
  final job = Job.forInsert(
    customerId: 1,
    summary: 'Billing test',
    description: '',
    siteId: null,
    contactId: null,
    billingContactId: null,
    status: JobStatus.inProgress,
    billingType: type,
    hourlyRate: MoneyEx.fromInt(10000),
    bookingFee: MoneyEx.zero,
  );
  await DaoJob().insert(job);
  return job;
}

Future<Task> _task(Job job, {BillingType? type}) async {
  final task = Task.forInsert(
    jobId: job.id,
    name: 'Test task',
    description: '',
    status: TaskStatus.approved,
    billingType: type,
  );
  await DaoTask().insert(task);
  return task;
}

Future<TimeEntry> _entry(Task task) async {
  final entry = TimeEntry.forInsert(
    taskId: task.id,
    startTime: DateTime(2025, 1, 1, 9),
    endTime: DateTime(2025, 1, 1, 10),
  );
  await DaoTimeEntry().insert(entry);
  return entry;
}

Future<Invoice> _invoice(Job job) async {
  final invoice = Invoice.forInsert(
    jobId: job.id,
    totalAmount: MoneyEx.fromInt(5000),
    dueDate: LocalDate.today(),
    billingContactId: 1,
  );
  await DaoInvoice().insert(invoice);
  return invoice;
}

Future<Milestone> _milestone(Quote quote, int number) async {
  final milestone = Milestone.forInsert(
    quoteId: quote.id,
    milestoneNumber: number,
    paymentAmount: MoneyEx.fromInt(5000),
    paymentPercentage: Percentage.fromInt(5000),
  );
  await DaoMilestone().insert(milestone);
  return milestone;
}
