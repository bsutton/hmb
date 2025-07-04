/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/ui/job/list_ready_to_invoice_screen.dart

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/app_title.dart';
import '../crud/job/job.g.dart';
import '../widgets/hmb_link_internal.dart';
import '../widgets/surface.dart';
import '../widgets/text/text.g.dart';
import '../widgets/widgets.g.dart' show HMBButton, HMBToast;
import 'dialog_select_tasks.dart';

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

  Future<void> _createInvoiceFor(Job job) async {
    final options = await selectTasksToInvoice(
      context: context,
      job: job,
      title: 'Tasks sto Invoice',
    );
    if (options != null) {
      try {
        if (options.selectedTaskIds.isNotEmpty || options.billBookingFee) {
          await createTimeAndMaterialsInvoice(
            job,
            options.contact,
            options.selectedTaskIds,
            groupByTask: options.groupByTask,
            billBookingFee: options.billBookingFee,
          );
          HMBToast.info('Invoice created for "${job.summary}".');
        } else {
          HMBToast.info('Select at least one Task or the Booking Fee.');
        }
      } catch (e) {
        HMBToast.error(
          'Failed to create invoice: $e',
          acknowledgmentRequired: true,
        );
      }
      await _loadJobs();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Surface(
      elevation: SurfaceElevation.e0,
      child: DeferredBuilder(
        this,
        builder: (context) {
          if (_jobs.isEmpty) {
            return const Center(child: Text('No jobs yet to invoice.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _jobs.length,
            itemBuilder: (context, index) {
              final job = _jobs[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Job summary as an internal link
                            HMBLinkInternal(
                              label: 'Job : #${job.id} ${job.summary}',
                              navigateTo: () async => JobEditScreen(job: job),
                            ),
                            const SizedBox(height: 4),
                            FutureBuilderEx<Customer?>(
                              // ignore: discarded_futures
                              future: DaoCustomer().getByJob(job.id),
                              builder: (ctx, customer) =>
                                  HMBText('Customer: ${customer?.name ?? '—'}'),
                            ),
                            const SizedBox(height: 4),
                            HMBText('Type: ${job.billingType.display}'),
                          ],
                        ),
                      ),
                      HMBButton(
                        label: 'Invoice',
                        hint: 'Create an invoice for this job',
                        // ignore: discarded_futures
                        onPressed: () => _createInvoiceFor(job),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
