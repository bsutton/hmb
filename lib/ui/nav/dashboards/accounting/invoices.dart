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

import 'package:flutter/material.dart';

import '../../../../dao/dao.g.dart';
import '../../../../util/dart/local_date.dart';
import '../dashlet_card.dart';

class InvoiceDashlet extends StatelessWidget {
  const InvoiceDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<InvoiceCountSummary>.route(
    label: 'Invoices',
    hint: 'Create, View, Upload and Send Invocies',
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
    if (invoice.paid) {
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
      summary.outstanding.toString(),
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 4),
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'overdue: ${summary.overdue}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.orange.shade700),
        ),
        const SizedBox(width: 8),
        Text(
          '7+: ${summary.overdueSevenDays}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.red.shade400),
        ),
      ],
    ),
    const SizedBox(height: 4),
    Text(
      'paid: ${summary.paid}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  ],
);
