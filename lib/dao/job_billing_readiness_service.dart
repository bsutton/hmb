import 'package:money2/money2.dart';

import '../entity/entity.g.dart';
import '../util/dart/money_ex.dart';
import 'dao_job.dart';
import 'dao_milestone.dart';
import 'dao_quote.dart';
import 'dao_task.dart';

enum JobBillingReasonCode {
  unbilledTimeAndMaterials,
  unbilledBookingFee,
  uninvoicedMilestone,
  unallocatedQuoteAmount,
  missingApprovedQuote,
}

class JobBillingReason {
  final JobBillingReasonCode code;
  final String label;
  final Money amount;
  final int count;
  final bool invoiceable;

  const JobBillingReason({
    required this.code,
    required this.label,
    required this.amount,
    required this.count,
    required this.invoiceable,
  });
}

class JobBillingReadiness {
  final Job job;
  final List<JobBillingReason> reasons;

  const JobBillingReadiness({required this.job, required this.reasons});

  bool get needsAttention => reasons.isNotEmpty;
  bool get canInvoice => reasons.any((reason) => reason.invoiceable);
  String get summary => reasons.map((reason) => reason.label).join(' • ');
}

/// Calculates billing attention independently from job lifecycle state.
class JobBillingReadinessService {
  Future<JobBillingReadiness> evaluate(Job job) async {
    if (job.billingType == BillingType.nonBillable || job.isStock) {
      return JobBillingReadiness(job: job, reasons: const []);
    }

    final reasons = <JobBillingReason>[];
    final tasks = await DaoTask().getTasksByJob(job.id);
    var timeAndMaterials = MoneyEx.zero;
    var timeAndMaterialsCount = 0;
    var hasFixedPriceWork = job.billingType == BillingType.fixedPrice;

    for (final task in tasks) {
      final type = task.effectiveBillingType(job.billingType);
      if (type == BillingType.fixedPrice) {
        hasFixedPriceWork = true;
        continue;
      }
      if (type != BillingType.timeAndMaterial) {
        continue;
      }
      final accrued = await DaoTask().getAccruedValueForTask(
        job: job,
        task: task,
        includeBilled: false,
      );
      final earned = await accrued.earned;
      if (earned.isPositive) {
        timeAndMaterials += earned;
        timeAndMaterialsCount++;
      }
    }
    if (timeAndMaterials.isPositive) {
      reasons.add(
        JobBillingReason(
          code: JobBillingReasonCode.unbilledTimeAndMaterials,
          label: 'Unbilled time/materials',
          amount: timeAndMaterials,
          count: timeAndMaterialsCount,
          invoiceable: true,
        ),
      );
    }

    if (await DaoJob().hasBillableBookingFee(job)) {
      reasons.add(
        JobBillingReason(
          code: JobBillingReasonCode.unbilledBookingFee,
          label: 'Unbilled booking fee',
          amount: await DaoJob().getBookingFee(job),
          count: 1,
          invoiceable: true,
        ),
      );
    }

    if (hasFixedPriceWork) {
      await _addFixedPriceReasons(job, reasons);
    }
    return JobBillingReadiness(job: job, reasons: reasons);
  }

  Future<void> _addFixedPriceReasons(
    Job job,
    List<JobBillingReason> reasons,
  ) async {
    final quotes = (await DaoQuote().getByJobId(
      job.id,
    )).where((quote) => quote.state.isPostApproval).toList();
    if (quotes.isEmpty) {
      if (job.status == JobStatus.completed) {
        reasons.add(
          JobBillingReason(
            code: JobBillingReasonCode.missingApprovedQuote,
            label: 'Billing setup required',
            amount: MoneyEx.zero,
            count: 1,
            invoiceable: false,
          ),
        );
      }
      return;
    }

    for (final quote in quotes) {
      final milestones = await DaoMilestone().getByQuoteId(quote.id);
      final uninvoiced = milestones
          .where((milestone) => milestone.invoiceId == null)
          .toList();
      if (uninvoiced.isNotEmpty) {
        final amount = uninvoiced.fold<Money>(
          MoneyEx.zero,
          (total, milestone) => total + milestone.paymentAmount,
        );
        reasons.add(
          JobBillingReason(
            code: JobBillingReasonCode.uninvoicedMilestone,
            label: '${uninvoiced.length} uninvoiced milestone(s)',
            amount: amount,
            count: uninvoiced.length,
            invoiceable: true,
          ),
        );
      }

      final allocated = milestones.fold<Money>(
        MoneyEx.zero,
        (total, milestone) => total + milestone.paymentAmount,
      );
      final unallocated = quote.totalAmount - allocated;
      if (unallocated.isPositive) {
        reasons.add(
          JobBillingReason(
            code: JobBillingReasonCode.unallocatedQuoteAmount,
            label: 'Quote amount not allocated to milestones',
            amount: unallocated,
            count: 1,
            invoiceable: false,
          ),
        );
      }
    }
  }
}
