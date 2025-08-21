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
import '../../entity/entity.g.dart';
import '../../util/exceptions.dart';

class InvoiceDetails {
  InvoiceDetails({
    required this.invoice,
    required this.job,
    required this.customer,
    required this.lineGroups,
  });

  static Future<InvoiceDetails> load(int invoiceId) async {
    final invoice = await DaoInvoice().getById(invoiceId);
    if (invoice == null) {
      throw InvoiceException('Invoice $invoiceId no longer exists');
    }

    final job = await DaoJob().getById(invoice.jobId);
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
