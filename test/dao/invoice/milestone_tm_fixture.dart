import 'package:hmb/dao/billing_service.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/fsm/lifecycle_event_dispatcher.dart';
import 'package:hmb/fsm/lifecycle_models.dart';
import 'package:hmb/fsm/quote_events.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../../ui/ui_test_helpers.dart';
import 'utility.dart' show createTask, createTimeEntry;

/// Persisted fixed contract with two payments and a separate T&M variation.
class MilestoneTmFixture {
  final Job job;
  final Task fixed;
  final Quote quote;
  final List<Milestone> milestones;
  final service = BillingService();

  MilestoneTmFixture(this.job, this.fixed, this.quote, this.milestones);

  static Future<MilestoneTmFixture> create() async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: MoneyEx.dollars(88),
      bookingFee: MoneyEx.zero,
    );
    final fixed = await createTask(job, 'Original fixed work');
    final quote = Quote.forInsert(
      jobId: job.id,
      summary: 'Original contract',
      description: '',
      totalAmount: MoneyEx.dollars(1000),
    );
    await DaoQuote().insert(quote);
    final group = QuoteLineGroup.forInsert(
      quoteId: quote.id,
      taskId: fixed.id,
      name: fixed.name,
    );
    await DaoQuoteLineGroup().insert(group);
    await DaoQuoteLine().insert(
      QuoteLine.forInsert(
        quoteId: quote.id,
        quoteLineGroupId: group.id,
        description: 'Agreed fixed scope',
        quantity: Fixed.one,
        unitCharge: MoneyEx.dollars(1000),
        lineTotal: MoneyEx.dollars(1000),
      ),
    );
    final milestones = <Milestone>[];
    for (var number = 1; number <= 2; number++) {
      final milestone = Milestone.forInsert(
        quoteId: quote.id,
        milestoneNumber: number,
        paymentAmount: MoneyEx.dollars(500),
        paymentPercentage: Percentage.fromInt(5000),
      );
      await DaoMilestone().insert(milestone);
      milestones.add(milestone);
    }
    await LifecycleEventDispatcher().dispatchQuote(
      quote.id,
      SendQuote.new,
      context: LifecycleContext(source: 'test'),
    );
    await LifecycleEventDispatcher().dispatchQuote(
      quote.id,
      ApproveQuoteEvent.new,
      context: LifecycleContext(source: 'test'),
    );
    return MilestoneTmFixture(job, fixed, quote, milestones);
  }

  Future<BillingPreview> preview() => service.preview(job.id);

  Future<Invoice> invoiceKeys(Iterable<String> keys) async =>
      await service.commit(
        (await preview()).select(keys: keys, contactId: job.billingContactId!),
      );

  Future<Invoice> invoiceMilestone(int index) =>
      invoiceKeys(['milestone:${milestones[index].id}']);

  Future<Task> addVariation([String name = 'Additional T&M work']) =>
      createTask(job, name, billingType: BillingType.timeAndMaterial);

  Future<TimeEntry> addLabour(Task task, {int hours = 2}) =>
      createTimeEntry(task, DateTime(2026, 1, 2, 11), Duration(hours: hours));
}
