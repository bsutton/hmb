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

/// Dashlet for active jobs count
library;

import 'package:material_ui/material_ui.dart';

import '../../../../dao/dao.g.dart';
import '../../../../util/dart/local_date.dart';
import '../../../widgets/hmb_tooltip.dart';
import '../dashlet_card.dart';

class InvoiceDashlet extends StatelessWidget {
  const InvoiceDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<InvoiceCountSummary>.route(
    label: 'Invoices',
    hint: 'Create, view, upload and send invoices',
    icon: Icons.receipt_long,
    value: getInvoiceCounts,
    route: '/home/accounting/invoices',
    valueBuilder: (context, dv) => buildInvoiceCountSummary(context, dv.value!),
  );

  Future<DashletValue<InvoiceCountSummary>> getInvoiceCounts() async =>
      DashletValue(await loadInvoiceCountSummary());
}

class InvoiceCountSummary {
  final int outstanding;
  final int paid;
  final int overdue;
  final int overdueSevenDays;

  const InvoiceCountSummary({
    required this.outstanding,
    required this.paid,
    required this.overdue,
    required this.overdueSevenDays,
  });
}

Future<InvoiceCountSummary> loadInvoiceCountSummary() async {
  final invoices = await DaoInvoice().getAll();
  final ledgerService = DebtorLedgerService();
  var outstanding = 0;
  var paid = 0;
  var overdue = 0;
  var overdueSevenDays = 0;
  final today = LocalDate.today();
  final sevenDayCutoff = today.subtractDays(7);
  for (final invoice in invoices) {
    if (invoice.isExternallyDeletedOrVoided) {
      continue;
    }
    final ledger = await ledgerService.invoiceSummary(invoice.id);
    if (!ledger.isOutstanding) {
      paid += 1;
      continue;
    }
    outstanding += 1;
    if (invoice.dueDate.isBefore(today)) {
      overdue += 1;
    }
    if (!invoice.dueDate.isAfter(sevenDayCutoff)) {
      overdueSevenDays += 1;
    }
  }
  return InvoiceCountSummary(
    outstanding: outstanding,
    paid: paid,
    overdue: overdue,
    overdueSevenDays: overdueSevenDays,
  );
}

Widget buildInvoiceCountSummary(
  BuildContext context,
  InvoiceCountSummary summary,
) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      '${summary.outstanding} unpaid '
      '${summary.outstanding == 1 ? 'invoice' : 'invoices'}',
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 4),
    _buildOverdueLine(context, summary),
  ],
);

Widget _buildOverdueLine(BuildContext context, InvoiceCountSummary summary) {
  final theme = Theme.of(context);
  if (summary.overdue > 0) {
    return HMBTooltip(
      hint:
          '${summary.overdue - summary.overdueSevenDays} invoices are '
          '1–6 days overdue; ${summary.overdueSevenDays} are '
          'at least 7 days overdue. These groups do not overlap.',
      child: Text(
        '${summary.overdue - summary.overdueSevenDays} overdue, '
        '${summary.overdueSevenDays} 7+ days',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: summary.overdueSevenDays > 0
              ? Colors.red.shade400
              : Colors.orange.shade700,
        ),
      ),
    );
  }
  return Text(
    'None overdue',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.bodySmall,
  );
}
