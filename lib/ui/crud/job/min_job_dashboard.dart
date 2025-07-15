/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../../dao/dao_invoice.dart';
import '../../../dao/dao_quote.dart';
import '../../../dao/dao_time_entry.dart';
import '../../../entity/job.dart';
import '../../invoicing/invoicing.g.dart';
import '../../nav/dashboards/dashlet_card.dart';
import '../../quoting/quoting.g.dart';
import 'esitmator/list_job_estimates_screen.dart';
import 'tracking/list_time_entry_screen.dart';

/// A compact dashboard for a single Job,
/// displaying fixed-size DashletCards in one or more rows.
class MiniJobDashboard extends StatelessWidget {
  const MiniJobDashboard({required this.job, super.key});
  final Job job;

  @override
  Widget build(BuildContext context) {
    const dashletSize = 90.0;
    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _dashlet(
            child: DashletCard<String>.builder(
              label: 'Estimate',
              hint: "Build an Estimate of a Job's cost",
              icon: Icons.calculate,
              compact: true,
              value: () async => const DashletValue(''),
              builder: (_, _) => JobEstimatesListScreen(job: job),
            ),
            size: dashletSize,
          ),
          _dashlet(
            child: DashletCard<int>.builder(
              label: 'Quotes',
              hint: 'Quote a job based on an Estimate',
              icon: Icons.format_quote,
              compact: true,
              value: () async {
                final all = await DaoQuote().getByFilter(null);
                final list = all.where((q) => q.jobId == job.id).toList();
                return DashletValue<int>(list.length);
              },
              builder: (_, _) => QuoteListScreen(job: job),
            ),
            size: dashletSize,
          ),
          _dashlet(
            child: DashletCard<int>.builder(
              label: 'Track',
              hint: 'Track and View time recorded against Job Tasks',
              icon: Icons.access_time,
              compact: true,
              value: () async {
                final list = await DaoTimeEntry().getByJob(job.id);
                return DashletValue<int>(list.length);
              },
              builder: (_, _) => TimeEntryListScreen(job: job),
            ),
            size: dashletSize,
          ),
          _dashlet(
            child: DashletCard<int>.builder(
              label: 'Invoices',
              hint: 'Invoice a Job',
              icon: Icons.attach_money,
              compact: true,
              value: () async {
                final all = await DaoInvoice().getByFilter(null);
                final list = all.where((i) => i.jobId == job.id).toList();
                return DashletValue<int>(list.length);
              },
              builder: (_, _) => InvoiceListScreen(job: job),
            ),
            size: dashletSize,
          ),
        ],
      ),
    );
  }

  /// Wraps a dashlet in a fixed-size container
  Widget _dashlet({required Widget child, required double size}) =>
      SizedBox(width: size, height: size, child: child);
}
