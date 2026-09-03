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

import '../../dao/dao.g.dart';
import '../../dao/invoice_billing_contact.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/exceptions.dart';

class InvoiceDetails {
  final Invoice invoice;
  final Job job;
  final Customer? customer;
  final Customer? billingCustomer;
  final ResolvedInvoiceBillingContact billingContact;
  final Contact? jobBillingContact;
  final InvoiceLedgerSummary ledger;
  final List<InvoiceLedgerHistoryEntry> ledgerHistory;
  final List<InvoiceLineGroupDetails> lineGroups;

  InvoiceDetails({
    required this.invoice,
    required this.job,
    required this.customer,
    required this.ledger,
    required this.ledgerHistory,
    required this.lineGroups,
    this.billingCustomer,
    this.billingContact = const ResolvedInvoiceBillingContact(
      contact: null,
      source: InvoiceBillingContactSource.missing,
    ),
    this.jobBillingContact,
  });

  static Future<InvoiceDetails> load(int invoiceId) async {
    final invoice = await DaoInvoice().getById(invoiceId);
    if (invoice == null) {
      throw InvoiceException('Invoice $invoiceId no longer exists');
    }

    final job = await DaoJob().getById(invoice.jobId);
    if (job == null) {
      throw InvoiceException('Job ${invoice.jobId} no longer exists');
    }
    final customer = job.customerId != null
        ? await DaoCustomer().getById(job.customerId)
        : null;
    final billingCustomer = await getBillingCustomerForJob(job);
    final billingContact = await resolveInvoiceBillingContact(
      invoice,
      job: job,
    );
    final jobBillingContact = await DaoContact().getBillingContactByJob(job);

    final lineGroups = await DaoInvoiceLineGroup().getByInvoiceId(invoice.id);
    final ledgerService = DebtorLedgerService();
    final ledger = await ledgerService.invoiceSummary(invoice.id);
    final ledgerHistory = await ledgerService.invoiceHistory(invoice.id);
    final groupDetails = <InvoiceLineGroupDetails>[];

    for (final g in lineGroups) {
      final lines = await DaoInvoiceLine().getByInvoiceLineGroupId(g.id);
      groupDetails.add(InvoiceLineGroupDetails(group: g, lines: lines));
    }

    return InvoiceDetails(
      invoice: invoice,
      job: job,
      customer: customer,
      billingCustomer: billingCustomer,
      billingContact: billingContact,
      jobBillingContact: jobBillingContact,
      ledger: ledger,
      ledgerHistory: ledgerHistory,
      lineGroups: groupDetails,
    );
  }
}

class InvoiceLineGroupDetails {
  final InvoiceLineGroup group;
  final List<InvoiceLine> lines;

  InvoiceLineGroupDetails({required this.group, required this.lines});
}
