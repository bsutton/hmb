import '../entity/entity.g.dart';
import 'dao.g.dart';

/// Runs in the background billing worker, never during rendering/navigation.
/// Shares candidate eligibility with invoice preparation.
class RemainingBilling {
  Future<JobBillingReasonCode?> check(int jobId) async {
    final job = await DaoJob().getById(jobId);
    if (job == null ||
        job.isStock ||
        job.status.stage == JobStatusStage.preStart ||
        job.status == JobStatus.rejected) {
      return null;
    }
    final readiness = await JobBillingReadinessService().evaluate(job);
    return readiness.reasons
            .where((reason) => reason.invoiceable)
            .firstOrNull
            ?.code ??
        readiness.reasons.firstOrNull?.code;
  }
}
