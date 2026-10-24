import 'package:money2/money2.dart';

import '../entity/entity.g.dart';
import '../util/dart/money_ex.dart';
import 'billing_service.dart';

enum JobBillingReasonCode {
  unbilledTimeAndMaterials,
  unbilledBookingFee,
  uninvoicedMilestone,
  unallocatedQuoteAmount,
  missingApprovedQuote,
  agreedFixedWork,
  futureFixedPayment;

  bool get invoiceable => switch (this) {
    unbilledTimeAndMaterials ||
    unbilledBookingFee ||
    uninvoicedMilestone ||
    agreedFixedWork => true,
    _ => false,
  };
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
    if (job.isStock || job.status == JobStatus.rejected) {
      return JobBillingReadiness(job: job, reasons: const []);
    }
    final preview = await BillingService().preview(
      job.id,
      forEligibility: true,
    );
    final reasons = <JobBillingReason>[];
    for (final candidate in preview.candidates) {
      if (candidate.amount.isZero) {
        continue;
      }
      reasons.add(
        JobBillingReason(
          code: candidate.isFuture
              ? JobBillingReasonCode.futureFixedPayment
              : switch (candidate.kind) {
                  'booking_fee' => JobBillingReasonCode.unbilledBookingFee,
                  'milestone' => JobBillingReasonCode.uninvoicedMilestone,
                  'quote' ||
                  'task_scope' => JobBillingReasonCode.agreedFixedWork,
                  _ => JobBillingReasonCode.unbilledTimeAndMaterials,
                },
          label: candidate.isFuture
              ? '${candidate.description} (future)'
              : candidate.description,
          amount: candidate.amount,
          count: 1,
          invoiceable: !candidate.isFuture,
        ),
      );
    }
    for (final reason in preview.blocked) {
      reasons.add(
        JobBillingReason(
          code: reason.contains('allocate the remaining amount')
              ? JobBillingReasonCode.unallocatedQuoteAmount
              : JobBillingReasonCode.missingApprovedQuote,
          label: reason,
          amount: MoneyEx.zero,
          count: 1,
          invoiceable: false,
        ),
      );
    }
    return JobBillingReadiness(job: job, reasons: reasons);
  }
}
