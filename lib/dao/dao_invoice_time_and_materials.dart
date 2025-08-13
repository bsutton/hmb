/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:fixed/fixed.dart';

import '../entity/entity.g.dart';
import '../util/exceptions.dart';
import '../util/local_date.dart';
import '../util/money_ex.dart';
import 'dao.g.dart';

Future<Invoice> createTimeAndMaterialsInvoice(
  Job job,
  Contact billingContact,
  List<int> selectedTaskIds, {
  required bool groupByTask,
  required bool billBookingFee,
}) async {
  if (job.hourlyRate == MoneyEx.zero) {
    throw InvoiceException("Hourly rate must be set for job '${job.summary}'");
  }

  assert(
    job.billingType == BillingType.timeAndMaterial ||
        (job.billingType == BillingType.fixedPrice && groupByTask),
    'FixedPrice must only use group by Task',
  );

  var totalAmount = MoneyEx.zero;

  final system = await DaoSystem().get();
  // Create invoice
  final invoice = Invoice.forInsert(
    jobId: job.id,
    totalAmount: totalAmount,
    dueDate: LocalDate.today().add(Duration(days: system.paymentTermsInDays)),
    billingContactId: billingContact.id,
  );

  final invoiceId = await DaoInvoice().insert(invoice);

  /// Fixed Price invoices don't have a Booking Fee as it is wrapped
  /// up in the total
  if (job.billingType == BillingType.timeAndMaterial) {
    final bookingFee = await DaoJob().getBookingFee(job);

    if (billBookingFee && bookingFee > MoneyEx.zero) {
      final invoiceLineGroup = InvoiceLineGroup.forInsert(
        invoiceId: invoiceId,
        name: 'Booking Fee',
      );
      await DaoInvoiceLineGroup().insert(invoiceLineGroup);

      final invoiceLine = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        invoiceLineGroupId: invoiceLineGroup.id,
        description: 'Booking Fee: ',
        quantity: Fixed.one,
        unitPrice: bookingFee,
        lineTotal: bookingFee,
        fromBookingFee: true,
      );

      job.bookingFeeInvoiced = true;
      await DaoJob().update(job);

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
