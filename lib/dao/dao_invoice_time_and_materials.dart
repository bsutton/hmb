import 'package:fixed/fixed.dart';

import '../entity/_index.g.dart';
import '../util/exceptions.dart';
import '../util/local_date.dart';
import '../util/money_ex.dart';
import '_index.g.dart';
import 'dao_invoice_create_by_date.dart';
import 'dao_invoice_create_by_task.dart';

Future<Invoice> createTimeAndMaterialsInvoice(
    Job job, List<int> selectedTaskIds,
    {required bool groupByTask}) async {
  if (job.hourlyRate == MoneyEx.zero) {
    throw InvoiceException('Hourly rate must be set for job ${job.summary}');
  }

  assert(
      job.billingType == BillingType.timeAndMaterial ||
          (job.billingType == BillingType.fixedPrice && groupByTask),
      'FixedPrice must only use group by Task');

  var totalAmount = MoneyEx.zero;

  // Create invoice
  final invoice = Invoice.forInsert(
      jobId: job.id,
      totalAmount: totalAmount,
      dueDate: LocalDate.today().add(const Duration(days: 1)));

  final invoiceId = await DaoInvoice().insert(invoice);

  /// Fixed Price invoices don't have a Booking Fee as it is wrapped
  /// up in the total
  if (job.billingType == BillingType.timeAndMaterial) {
    final bookingFee = await DaoJob().getBookingFee(job);

    if (bookingFee > MoneyEx.zero) {
      final invoiceLineGroup =
          InvoiceLineGroup.forInsert(invoiceId: invoiceId, name: 'Booking Fee');
      await DaoInvoiceLineGroup().insert(invoiceLineGroup);

      final invoiceLine = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        invoiceLineGroupId: invoiceLineGroup.id,
        description: 'Booking Fee: ',
        quantity: Fixed.one,
        unitPrice: bookingFee,
        lineTotal: bookingFee,
      );
      await DaoInvoiceLine().insert(invoiceLine);

      totalAmount += bookingFee;
    }
  }

  // Group by task: Create invoice line group for the task
  if (groupByTask) {
    totalAmount += await createByTask(invoiceId, job, selectedTaskIds);
  }
  // Group by date
  else {
    totalAmount += await createByDate(job, invoiceId, selectedTaskIds);
  }

  // Update the invoice total amount
  final updatedInvoice = invoice.copyWith(
    id: invoiceId,
    totalAmount: totalAmount,
  );
  await DaoInvoice().update(updatedInvoice);

  return updatedInvoice;
}
