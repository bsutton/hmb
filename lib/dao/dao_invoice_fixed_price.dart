import '../entity/entity.g.dart';
import 'billing_service.dart';
import 'dao_job.dart';

/// Compatibility entry point; milestone ownership is committed atomically.
Future<Invoice> createInvoiceFromMilestone(
  Milestone milestonePayment,
  Contact billingContact,
) async {
  final service = BillingService();
  final job = await DaoJob().getJobForQuote(milestonePayment.quoteId);
  final preview = await service.preview(job.id);
  return await service.commit(
    preview.select(
      keys: ['milestone:${milestonePayment.id}'],
      contactId: billingContact.id,
    ),
  );
}
