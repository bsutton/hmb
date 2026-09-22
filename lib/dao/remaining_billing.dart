import '../entity/entity.g.dart';
import '../util/dart/money_ex.dart';
import 'dao.g.dart';

/// Existence check, not a job valuation. Stops at the first unbilled source.
/// Run only in the billing worker, never on the navigation/rendering path.
class RemainingBilling {
  Future<JobBillingReasonCode?> check(int jobId) async {
    final job = await DaoJob().getById(jobId);
    if (job == null ||
        job.isStock ||
        job.status.stage == JobStatusStage.preStart ||
        job.status == JobStatus.rejected) {
      return null;
    }

    // Source links survive progress invoices. An invoice on the job is NOT
    // proof that all its time, materials or milestones have been billed.
    final quotes = (await DaoQuote().getByJobId(
      jobId,
    )).where((quote) => quote.state.isPostApproval).toList();
    final quotedTasks = <int>{};
    for (final quote in quotes) {
      for (final group in await DaoQuoteLineGroup().getByQuoteId(quote.id)) {
        if (group.taskId != null) {
          quotedTasks.add(group.taskId!);
        }
      }
      final milestones = await DaoMilestone().getByQuoteId(quote.id);
      var allocated = MoneyEx.zero;
      for (final milestone in milestones) {
        allocated += milestone.paymentAmount;
        if (!milestone.paymentAmount.isZero &&
            (milestone.invoiceId == null ||
                await DaoInvoice().getById(milestone.invoiceId) == null)) {
          return JobBillingReasonCode.uninvoicedMilestone;
        }
      }
      if (quote.totalAmount > allocated) {
        return JobBillingReasonCode.unallocatedQuoteAmount;
      }
    }

    for (final task in await DaoTask().getTasksByJob(jobId)) {
      if (task.status == TaskStatus.cancelled) {
        continue;
      }
      final type = task.effectiveBillingType(job.billingType);
      if (type == BillingType.nonBillable) {
        continue;
      }
      // Fixed-price quote work is covered by its milestones, not timesheets
      // or materials consumed in delivering that quote.
      if (type == BillingType.fixedPrice &&
          ((job.billingType == BillingType.fixedPrice && quotes.isNotEmpty) ||
              quotedTasks.contains(task.id))) {
        continue;
      }
      if (type == BillingType.timeAndMaterial) {
        final rate = await DaoTask().getHourlyRate(task);
        if (!rate.isZero) {
          for (final entry in await DaoTimeEntry().getByTask(task.id)) {
            if (entry.billable &&
                !entry.billed &&
                entry.endTime != null &&
                !entry.hours.isZero) {
              return JobBillingReasonCode.unbilledTimeAndMaterials;
            }
          }
        }
      }
      for (final item in await DaoTaskItem().getByTask(task.id)) {
        if (item.billed || !item.completed) {
          continue;
        }
        if (type == BillingType.timeAndMaterial) {
          if (item.itemType != TaskItemType.labour &&
              !item.calcMaterialCost(type).lineChargeTotal.isZero) {
            return JobBillingReasonCode.unbilledTimeAndMaterials;
          }
        } else if (item.itemType != TaskItemType.toolsOwn &&
            !item
                .getTotalLineCharge(type, job.hourlyRate ?? MoneyEx.zero)
                .isZero) {
          if (job.billingType == BillingType.fixedPrice && quotes.isEmpty) {
            return JobBillingReasonCode.missingApprovedQuote;
          }
          return JobBillingReasonCode.unbilledTimeAndMaterials;
        }
      }
    }

    if (await DaoJob().hasBillableBookingFee(job)) {
      // Legacy booking_fee_invoiced can disagree with the actual fee line.
      // Honour an existing fee invoice without rewriting historical flags.
      final lines = await DaoJob().db.rawQuery(
        '''
SELECT 1 FROM invoice_line line JOIN invoice i ON i.id = line.invoice_id
WHERE i.job_id = ? AND line.from_booking_fee = 1
  AND i.external_sync_status NOT IN (2, 3) LIMIT 1
''',
        [jobId],
      );
      if (lines.isEmpty) {
        return JobBillingReasonCode.unbilledBookingFee;
      }
    }
    return null;
  }
}
