import '../../dao/_index.g.dart';
import '../../entity/_index.g.dart';

class InvoiceDetails {
  InvoiceDetails({
    required this.invoice,
    required this.job,
    required this.customer,
    required this.lineGroups,
  });

  static Future<InvoiceDetails> load(int invoiceId) async {
    final invoice = await DaoInvoice().getById(invoiceId);

    final job = await DaoJob().getById(invoice!.jobId);
    final customer = job?.customerId != null
        ? await DaoCustomer().getById(job!.customerId)
        : null;

    final lineGroups = await DaoInvoiceLineGroup().getByInvoiceId(invoice.id);
    final groupDetails = <InvoiceLineGroupDetails>[];

    for (final g in lineGroups) {
      final lines = await DaoInvoiceLine().getByInvoiceLineGroupId(g.id);
      groupDetails.add(InvoiceLineGroupDetails(group: g, lines: lines));
    }

    return InvoiceDetails(
      invoice: invoice,
      job: job!,
      customer: customer,
      lineGroups: groupDetails,
    );
  }

  final Invoice invoice;
  final Job job;
  final Customer? customer;
  final List<InvoiceLineGroupDetails> lineGroups;
}

class InvoiceLineGroupDetails {
  InvoiceLineGroupDetails({required this.group, required this.lines});

  final InvoiceLineGroup group;
  final List<InvoiceLine> lines;
}