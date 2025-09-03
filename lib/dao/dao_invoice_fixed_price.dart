/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// ignore_for_file: lines_longer_than_80_chars

import 'package:money2/money2.dart';

import '../entity/entity.g.dart';
import '../util/dart/exceptions.dart';
import '../util/dart/local_date.dart';
import '../util/dart/money_ex.dart';
import 'dao.g.dart';

Future<Invoice> createFixedPriceInvoice(
  Quote quote,
  Contact billingContact,
) async {
  final job = await DaoJob().getById(quote.jobId);
  if (job!.hourlyRate == MoneyEx.zero) {
    throw InvoiceException("Hourly rate must be set for job '${job.summary}'");
  }

  final totalAmount = quote.totalAmount;

  // Create invoice
  final invoice = Invoice.forInsert(
    jobId: job.id,
    totalAmount: totalAmount,
    dueDate: LocalDate.today().add(const Duration(days: 1)),
    billingContactId: billingContact.id,
  );

  final invoiceId = await DaoInvoice().insert(invoice);

  final invoiceLineGroup = InvoiceLineGroup.forInsert(
    invoiceId: invoiceId,
    name: 'Total',
  );
  await DaoInvoiceLineGroup().insert(invoiceLineGroup);

  final invoiceLine = InvoiceLine.forInsert(
    invoiceLineGroupId: invoiceLineGroup.id,
    invoiceId: invoiceId,
    description: job.summary,
    quantity: Fixed.one,
    unitPrice: totalAmount,
    lineTotal: totalAmount,
  );
  await DaoInvoiceLine().insert(invoiceLine);

  // Update the invoice total amount
  final updatedInvoice = invoice.copyWith(totalAmount: totalAmount);
  await DaoInvoice().update(updatedInvoice);

  return updatedInvoice;
}

Future<Invoice> createInvoiceFromMilestone(
  Milestone milestonePayment,
  Contact billingContact,
) async {
  final job = await DaoJob().getJobForQuote(milestonePayment.quoteId);

  final invoice = Invoice.forInsert(
    jobId: job.id,
    dueDate: LocalDate.today().add(const Duration(days: 1)),
    totalAmount: milestonePayment.paymentAmount,
    billingContactId: billingContact.id,
  );

  final invoiceId = await DaoInvoice().insert(invoice);

  final invoiceLineGroup = InvoiceLineGroup.forInsert(
    invoiceId: invoiceId,
    name: 'Milestone #${milestonePayment.milestoneNumber}',
  );
  await DaoInvoiceLineGroup().insert(invoiceLineGroup);

  // Create an InvoiceLine for this milestone
  final invoiceLine = InvoiceLine.forInsert(
    invoiceId: invoiceId,
    invoiceLineGroupId: invoiceLineGroup.id,
    description:
        milestonePayment.milestoneDescription ??
        'Milestone Payment ${milestonePayment.milestoneNumber}',
    quantity: Fixed.fromInt(1, decimalDigits: 0),
    unitPrice: milestonePayment.paymentAmount,
    lineTotal: milestonePayment.paymentAmount,
  );

  await DaoInvoiceLine().insert(invoiceLine);

  return invoice;
}
