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
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../dao/dao.g.dart';
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
  late List<ToBeInvoicedJob> _jobs;

  @override
  Future<void> asyncInitState() async {
    await _loadJobs();
  }

  Future<void> _loadJobs() async {
    _jobs = await _fetchReadyJobs();
    setState(() {});
  }

  Future<List<ToBeInvoicedJob>> _fetchReadyJobs([String? filter]) async {
    final jobs = await DaoJob().readyToBeInvoiced(filter);
    final unsentJobIds = (await DaoInvoice().getUnsent())
        .map((invoice) => invoice.jobId)
        .toSet();

    final ready = <ToBeInvoicedJob>[];
    for (final job in jobs) {
      ready.add(
        ToBeInvoicedJob(
          job: job,
          hasUnsentInvoice: unsentJobIds.contains(job.id),
          readiness: await JobBillingReadinessService().evaluate(job),
        ),
      );
    }
    return ready;
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => HMBListPage(
      emptyMessage: 'No jobs yet to invoice.',

      itemCount: _jobs.length,
      itemBuilder: (context, index) {
        final item = _jobs[index];
        final job = item.job;

        return FutureBuilderEx(
          future: DaoCustomer().getByJob(job.id),
          builder: (context, customer) => HMBListCard(
            title: 'Customer: ${customer?.name ?? '—'}',
            actions: [
              HMBButton(
                label: item.readiness.canInvoice ? 'Invoice' : 'Set up billing',
                hint: item.readiness.canInvoice
                    ? 'Create an invoice for this job'
                    : 'Open the quote and milestone billing setup',
                onPressed: () async {
                  if (item.readiness.canInvoice) {
                    await createInvoiceFor(job, context);
                    return;
                  }
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FullPageListJobCard(job),
                    ),
                  );
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
              HMBText(
                'Attention: ${item.readiness.summary}',
                color: Colors.orange,
              ),
              if (item.hasUnsentInvoice)
                const HMBText(
                  'Pending invoice exists and has not been sent yet.',
                  color: Colors.orange,
                ),
            ],
          ),
        );
      },
    ),
  );
}

class ToBeInvoicedJob {
  final Job job;
  final bool hasUnsentInvoice;
  final JobBillingReadiness readiness;

  const ToBeInvoicedJob({
    required this.job,
    required this.hasUnsentInvoice,
    required this.readiness,
  });
}
