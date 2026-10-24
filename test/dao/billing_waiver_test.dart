import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/billing_attention_cache.dart';
import 'package:hmb/dao/billing_queue.dart';
import 'package:hmb/dao/billing_service.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/task_fixed_agreement.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';
import '../util/settings_test_helper.dart';

void main() {
  late Job job;
  late Task task;
  late TimeEntry entry;
  final service = BillingService();
  setUpAll(prepareSettingsTest);
  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
    job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      status: JobStatus.completed,
      hourlyRate: MoneyEx.dollars(88),
      bookingFee: MoneyEx.zero,
    );
    task = Task.forInsert(
      jobId: job.id,
      name: 'Additional tile',
      description: '',
      status: TaskStatus.completed,
    );
    await DaoTask().insert(task);
    entry = TimeEntry.forInsert(
      taskId: task.id,
      startTime: DateTime(2026, 5, 12, 10, 30),
      endTime: DateTime(2026, 5, 12, 11, 15),
    );
    await DaoTimeEntry().insert(entry);
  });
  tearDown(tearDownTestDb);

  Future<void> waive() async {
    final preview = await service.preview(job.id);
    await service.waiveCharges(
      preview: preview,
      keys: ['time:${entry.id}'],
      reason: 'Missed billing; too late to charge',
    );
  }

  test(
    'waiver removes work from billing without invoicing or marking billed',
    () async {
      await BillingQueue(testDb!).drain(limit: 10000);
      expect(
        (await DaoJob().readyToBeInvoiced(null)).map((job) => job.id),
        contains(job.id),
      );
      await waive();
      final preview = await service.preview(job.id);
      expect(preview.candidates, isEmpty);
      expect(preview.waivers.single.amount, MoneyEx.dollars(66));
      expect(
        preview.waivers.single.reason,
        'Missed billing; too late to charge',
      );
      expect((await DaoTimeEntry().getById(entry.id))!.billed, isFalse);
      expect(await DaoInvoice().getByJobId(job.id), isEmpty);
      expect(
        (await JobBillingReadinessService().evaluate(job)).needsAttention,
        isFalse,
      );
      await BillingQueue(testDb!).drain(limit: 10000);
      expect(
        (await DaoJob().readyToBeInvoiced(null)).map((job) => job.id),
        isNot(contains(job.id)),
      );
      final cache = BillingAttentionCache();
      addTearDown(cache.dispose);
      await cache.refresh();
      expect(
        cache.entries!.map((entry) => entry.job.id),
        isNot(contains(job.id)),
      );
    },
  );

  test('new work remains billable and undo preserves waiver history', () async {
    await waive();
    final newEntry = TimeEntry.forInsert(
      taskId: task.id,
      startTime: DateTime(2026, 6, 1, 9),
      endTime: DateTime(2026, 6, 1, 10),
    );
    await DaoTimeEntry().insert(newEntry);
    var preview = await service.preview(job.id);
    expect(preview.candidates.map((c) => c.key), ['time:${newEntry.id}']);
    await service.restoreWaiver(
      jobId: job.id,
      waiverId: preview.waivers.single.id,
    );
    preview = await service.preview(job.id);
    expect(preview.candidates, hasLength(2));
    expect(preview.waivers.single.restoredDate, isNotNull);
    await waive();
    expect((await service.preview(job.id)).waivers, hasLength(2));
  });

  test('editing waived work makes the changed charge visible again', () async {
    await waive();
    await DaoTimeEntry().update(
      entry.copyWith(endTime: DateTime(2026, 5, 12, 12)),
    );
    final preview = await service.preview(job.id);
    expect(preview.candidates.single.amount, MoneyEx.dollars(132));
    expect(preview.waivers.single.amount, MoneyEx.dollars(66));
  });

  test('waiver invalidates an already prepared invoice plan', () async {
    final preview = await service.preview(job.id);
    final plan = preview.select(
      keys: ['time:${entry.id}'],
      contactId: job.billingContactId!,
    );
    await waive();
    await expectLater(service.commit(plan), throwsException);
    expect(await DaoInvoice().getByJobId(job.id), isEmpty);
  });

  test('stale, empty and invalid selections never waive any work', () async {
    final preview = await service.preview(job.id);
    await expectLater(
      service.waiveCharges(
        preview: preview,
        keys: ['time:${entry.id}'],
        reason: ' ',
      ),
      throwsException,
    );
    await expectLater(
      service.waiveCharges(
        preview: preview,
        keys: ['time:${entry.id}', 'time:-1'],
        reason: 'No charge',
      ),
      throwsException,
    );
    await DaoTimeEntry().update(entry.copyWith(billed: true));
    await expectLater(
      service.waiveCharges(
        preview: preview,
        keys: ['time:${entry.id}'],
        reason: 'No charge',
      ),
      throwsException,
    );
    expect(await testDb!.query('billing_waiver'), isEmpty);
  });

  test('waiving labour does not waive an independent booking fee', () async {
    job.bookingFee = MoneyEx.dollars(100);
    await DaoJob().update(job);
    await waive();
    final preview = await service.preview(job.id);
    expect(preview.candidates.single.kind, 'booking_fee');
    await service.waiveCharges(
      preview: preview,
      keys: preview.candidates.map((charge) => charge.key),
      reason: 'Booking fee waived',
    );
    expect((await service.preview(job.id)).candidates, isEmpty);
    expect((await DaoJob().getById(job.id))!.bookingFeeInvoiced, isFalse);
  });

  for (final kind in ['quote', 'milestone', 'task_scope']) {
    test('$kind can be waived and restored independently of labour', () async {
      final fixed = Task.forInsert(
        jobId: job.id,
        name: 'Fixed addition',
        description: '',
        status: TaskStatus.completed,
        billingType: BillingType.fixedPrice,
      );
      await DaoTask().insert(fixed);
      if (kind == 'task_scope') {
        await testDb!.transaction(
          (txn) => TaskFixedAgreement().save(
            txn,
            fixed,
            MoneyEx.dollars(80),
            'Agreed price',
          ),
        );
      } else {
        final quote = Quote.forInsert(
          jobId: job.id,
          summary: 'Fixed addition',
          description: '',
          totalAmount: MoneyEx.dollars(80),
          state: QuoteState.approved,
        );
        await DaoQuote().insert(quote);
        await DaoQuoteLineGroup().insert(
          QuoteLineGroup.forInsert(
            quoteId: quote.id,
            taskId: fixed.id,
            name: fixed.name,
          ),
        );
        if (kind == 'milestone') {
          await DaoMilestone().insert(
            Milestone.forInsert(
              quoteId: quote.id,
              milestoneNumber: 1,
              paymentAmount: MoneyEx.dollars(80),
              paymentPercentage: Percentage.fromInt(100),
            ),
          );
        }
      }
      var preview = await service.preview(job.id);
      final charge = preview.candidates.singleWhere((c) => c.kind == kind);
      await service.waiveCharges(
        preview: preview,
        keys: [charge.key],
        reason: 'Agreed not to charge',
      );
      preview = await service.preview(job.id);
      expect(preview.candidates.map((c) => c.key), ['time:${entry.id}']);
      await service.restoreWaiver(
        jobId: job.id,
        waiverId: preview.waivers.single.id,
      );
      expect(
        (await service.preview(job.id)).candidates.map((c) => c.key),
        contains(charge.key),
      );
    });
  }
}
