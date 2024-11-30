import 'package:money2/money2.dart';

import '../entity/_index.g.dart';
import '../entity/milestone.dart';
import '../util/exceptions.dart';
import '../util/local_date.dart';
import '../util/money_ex.dart';
import '_index.g.dart';
import 'dao_milestone.dart';

Future<Invoice> createFixedPriceInvoice(
  Job job,
  String paymentDescription,
  Percentage? percentage,
  Money? progressAmount,
) async {
  assert(
      percentage != null && progressAmount == null ||
          percentage == null && progressAmount != null,
      '''
Either precentage or progressAmount must be null and the other not null''');
  if (job.hourlyRate == MoneyEx.zero) {
    throw InvoiceException('Hourly rate must be set for job ${job.summary}');
  }

  final totalAmount = MoneyEx.zero;

  // Create invoice
  final invoice = Invoice.forInsert(
      jobId: job.id,
      totalAmount: totalAmount,
      dueDate: LocalDate.today().add(const Duration(days: 1)));

  final invoiceId = await DaoInvoice().insert(invoice);

  if (percentage != null) {
    progressAmount = (await DaoJob().getFixedPriceTotal(job))
        .multipliedByPercentage(percentage);
  }

  final invoiceLine = InvoiceLine.forInsert(
      invoiceId: invoiceId,
      description: paymentDescription,
      quantity: Fixed.one,
      unitPrice: progressAmount!,
      lineTotal: progressAmount);
  await DaoInvoiceLine().insert(invoiceLine);

  // Update the invoice total amount
  final updatedInvoice = invoice.copyWith(
    id: invoiceId,
    totalAmount: progressAmount,
  );
  await DaoInvoice().update(updatedInvoice);

  return updatedInvoice;
}

Future<Invoice> createInvoiceFromMilestonePayment(
    Milestone milestonePayment) async {
  final job = await DaoJob().getJobForQuote(milestonePayment.quoteId);

  final invoice = Invoice.forInsert(
    jobId: job.id,
    dueDate: LocalDate.today().add(const Duration(days: 1)),
    totalAmount: milestonePayment.paymentAmount!,
  );

  final invoiceId = await DaoInvoice().insert(invoice);

  // Create an InvoiceLine for this milestone
  final invoiceLine = InvoiceLine.forInsert(
    invoiceId: invoiceId,
    description: milestonePayment.milestoneDescription ??
        'Milestone Payment ${milestonePayment.milestoneNumber}',
    quantity: Fixed.fromInt(1),
    unitPrice: milestonePayment.paymentAmount!,
    lineTotal: milestonePayment.paymentAmount!,
  );

  await DaoInvoiceLine().insert(invoiceLine);

  // Update milestone payment status
  final updatedMilestonePayment = milestonePayment.copyWith(status: 'invoiced');
  await DaoMilestone().update(updatedMilestonePayment);

  return invoice.copyWith(id: invoiceId);
}
