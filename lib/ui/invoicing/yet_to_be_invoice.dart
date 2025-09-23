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

// lib/src/ui/job/list_ready_to_invoice_screen.dart

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/flutter/app_title.dart';
import '../crud/job/full_page_list_job_card.dart';
import '../widgets/hmb_link_internal.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/text/text.g.dart';
import '../widgets/widgets.g.dart' show HMBButton;
import 'create_invoice_ui.dart';

class YetToBeInvoicedScreen extends StatefulWidget {
  YetToBeInvoicedScreen({super.key}) {
    // Renamed title as requested
    setAppTitle('To Be Invoiced');
  }

  @override
  _YetToBeInvoicedScreenState createState() => _YetToBeInvoicedScreenState();
}

class _YetToBeInvoicedScreenState extends DeferredState<YetToBeInvoicedScreen> {
  late List<Job> _jobs;

  @override
  Future<void> asyncInitState() async {
    await _loadJobs();
  }

  Future<void> _loadJobs() async {
    _jobs = await _fetchReadyJobs();
    setState(() {});
  }

  Future<List<Job>> _fetchReadyJobs([String? filter]) =>
      DaoJob().readyToBeInvoiced(filter);

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => HMBListPage(
      emptyMessage: 'No jobs yet to invoice.',

      itemCount: _jobs.length,
      itemBuilder: (context, index) {
        final job = _jobs[index];

        return FutureBuilderEx(
          future: DaoCustomer().getByJob(job.id),
          builder: (context, customer) => HMBListCard(
            title: 'Customer: ${customer?.name ?? '—'}',
            actions: [
              HMBButton(
                label: 'Invoice',
                hint: 'Create an invoice for this job',
                // ignore: discarded_futures
                onPressed: () async {
                  await createInvoiceFor(job, context);
                },
              ),
            ],
            children: [
              // Job summary as an internal link
              HMBLinkInternal(
                label: 'Job : #${job.id} ${job.summary}',
                navigateTo: () async => FullPageListJobCard(job),
              ),
              const HMBSpacer(height: true),
              HMBText('Type: ${job.billingType.display}'),
            ],
          ),
        );
      },
    ),
  );
}
