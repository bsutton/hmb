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
  final bool hasOverdueOutstanding;

  const InvoiceCountSummary({
    required this.outstanding,
    required this.paid,
    required this.hasOverdueOutstanding,
  });
}

Future<InvoiceCountSummary> loadInvoiceCountSummary() async {
  final invoices = await DaoInvoice().getAll();
  var outstanding = 0;
  var paid = 0;
  var hasOverdueOutstanding = false;
  final overdueCutoff = LocalDate.today().subtractDays(3);
  for (final invoice in invoices) {
    if (invoice.isExternallyDeletedOrVoided) {
      continue;
    }
    if (invoice.paid) {
      paid += 1;
      continue;
    }
    outstanding += 1;
    if (invoice.dueDate.isBefore(overdueCutoff)) {
      hasOverdueOutstanding = true;
    }
  }
  return InvoiceCountSummary(
    outstanding: outstanding,
    paid: paid,
    hasOverdueOutstanding: hasOverdueOutstanding,
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
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: summary.hasOverdueOutstanding ? Colors.red : null,
      ),
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
