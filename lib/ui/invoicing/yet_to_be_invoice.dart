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

import '../../dao/billing_attention_cache.dart';
import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/flutter/app_title.dart';
import '../crud/job/full_page_list_job_card.dart';
import '../widgets/hmb_link_internal.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/text/text.g.dart';
import '../widgets/widgets.g.dart' show BlockingUI, HMBButton, HMBToast;
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
    await BlockingUI().runAndWait(() async {
      _jobs = await _fetchReadyJobs();
    });
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reloadAfterAction() async {
    if (!mounted) {
      return;
    }
    try {
      await _loadJobs();
    } catch (error) {
      HMBToast.error('Could not refresh billing attention. Reopen to retry.');
    }
  }

  Future<List<ToBeInvoicedJob>> _fetchReadyJobs() async {
    final cache = BillingAttentionCache.instance;
    await cache.refresh();
    if (cache.error != null) {
      throw StateError(
        'Could not refresh billing attention. Please try again.',
      );
    }
    final unsentJobIds = (await DaoInvoice().getUnsent())
        .map((invoice) => invoice.jobId)
        .toSet();

    final ready = <ToBeInvoicedJob>[];
    for (final readiness in cache.entries!) {
      final job = readiness.job;
      ready.add(
        ToBeInvoicedJob(
          job: job,
          hasUnsentInvoice: unsentJobIds.contains(job.id),
          readiness: readiness,
        ),
      );
    }
    return ready;
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    waitingBuilder: (_) => const SizedBox.shrink(),
    errorBuilder: (_, error) => const Center(
      child: Text(
        'Could not load billing attention. Reopen this screen to retry.',
      ),
    ),
    builder: (context) => HMBListPage(
      emptyMessage: 'No jobs yet to invoice.',

      itemCount: _jobs.length,
      itemBuilder: (context, index) {
        final item = _jobs[index];
        final job = item.job;

        return FutureBuilderEx(
          future: DaoCustomer().getById(job.customerId),
          waitingBuilder: (_) => const SizedBox.shrink(),
          errorBuilder: (_, error) => const Text('Could not load customer.'),
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
                    await _reloadAfterAction();
                    return;
                  }
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FullPageListJobCard(job),
                    ),
                  );
                  await _reloadAfterAction();
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
