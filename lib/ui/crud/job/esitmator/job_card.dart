/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../../../dao/dao.g.dart';
import '../../../../entity/job.dart';
import '../../../../entity/task_item_type.dart';
import '../../../../util/money_ex.dart';
import '../../../invoicing/dialog_select_tasks.dart';
import '../../../quoting/quote_details_screen.dart';
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/text/hmb_text_themes.dart';
import '../../../widgets/widgets.g.dart';
import '../edit_job_screen.dart';
import 'edit_job_estimate_screen.dart';

class JobCard extends StatefulWidget {
  const JobCard({
    required this.job,
    required this.onEstimatesUpdated,
    super.key,
  });

  final Job job;
  final VoidCallback onEstimatesUpdated;

  @override
  _JobCardState createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  @override
  Widget build(BuildContext context) => FutureBuilderEx<CompleteJobInfo>(
    // ignore: discarded_futures
    future: _loadCompleteJobInfo(widget.job),
    builder: (context, info) {
      final labourCharges = info!.totals.labourCharges;
      final materialCharges = info.totals.materialsCharges;
      final combinedCharges = labourCharges + materialCharges;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.job.summary,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          HMBLinkInternal(
            label: 'Job #: ${widget.job.id}',
            navigateTo: () async => JobEditScreen(job: widget.job),
          ),

          if (info.quoteNumber != null)
            HMBLinkInternal(
              label: 'Quote #: ${info.quoteNumber}',
              navigateTo: () async =>
                  QuoteDetailsScreen(quoteId: info.quoteId!),
            ),

          HMBTextLine('Status: ${info.statusName}'),
          HMBTextLine('Labour: $labourCharges'),
          HMBTextLine('Materials: $materialCharges'),
          HMBTextLine('Combined: $combinedCharges'),
          const HMBSpacer(height: true),
          Row(
            children: [
              HMBButton(
                label: 'Update Estimates',
                hint: 'Add/Edit labour and materials costs to Job',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          JobEstimateBuilderScreen(job: widget.job),
                    ),
                  );
                  // After returning, refresh totals
                  widget.onEstimatesUpdated();
                },
              ),
              const HMBSpacer(width: true),
              HMBButton(
                label: 'Create Quote',
                hint: 'Create a Fixed price Quote based on your Estimates',
                onPressed: () async {
                  await _createQuote();
                  widget.onEstimatesUpdated();
                },
              ),
            ],
          ),
        ],
      );
    },
  );

  Future<void> _createQuote() async {
    final invoiceOptions = await selectTaskToQuote(
      context: context,
      job: widget.job,
      title: 'Tasks for Quote',
    );

    if (invoiceOptions != null) {
      try {
        if (!invoiceOptions.billBookingFee &&
            invoiceOptions.selectedTaskIds.isEmpty) {
          HMBToast.error(
            'You must select a task or the booking Fee',
            acknowledgmentRequired: true,
          );
          return;
        }
        await DaoQuote().create(widget.job, invoiceOptions);
        HMBToast.info('Quote created successfully.');
      } catch (e) {
        HMBToast.error(
          'Failed to create quote: $e',
          acknowledgmentRequired: true,
        );
      }
    }
  }

  Future<CompleteJobInfo> _loadCompleteJobInfo(Job job) async {
    final totals = await _loadJobTotals(job);
    final customer = job.customerId != null
        ? await DaoCustomer().getById(job.customerId)
        : null;
    final jobStatus = job.status;

    final customerName = customer?.name ?? 'N/A';
    final statusName = jobStatus.name;

    // Fetch the quotes for this job and pick the most recent one
    final quotes = await DaoQuote().getByJobId(job.id);
    String? quoteNumber;
    int? quoteId;
    if (quotes.isNotEmpty) {
      // Sort quotes by modified date descending
      quotes.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
      final latestQuote = quotes.first;
      quoteNumber = latestQuote.bestNumber;
      quoteId = latestQuote.id;
    }

    return CompleteJobInfo(
      totals: totals,
      customerName: customerName,
      statusName: statusName,
      quoteNumber: quoteNumber,
      quoteId: quoteId,
    );
  }

  Future<JobTotals> _loadJobTotals(Job job) async {
    final tasks = await DaoTask().getTasksByJob(job.id);
    var totalLabour = MoneyEx.zero;
    var totalMaterials = MoneyEx.zero;

    for (final task in tasks) {
      final items = await DaoTaskItem().getByTask(task.id);
      final hourlyRate = await DaoTask().getHourlyRate(task);
      final billingType = await DaoTask().getBillingType(task);

      for (final item in items) {
        if (item.itemType == TaskItemType.labour) {
          totalLabour += item.calcLabourCharges(hourlyRate);
        } else {
          totalMaterials += item.calcMaterialCharges(billingType);
        }
      }
    }

    return JobTotals(
      labourCharges: totalLabour,
      materialsCharges: totalMaterials,
    );
  }
}

/// Holds totals for a job
class JobTotals {
  JobTotals({required this.labourCharges, required this.materialsCharges});

  final Money labourCharges;
  final Money materialsCharges;
}

/// Holds all required details for displaying the job card fields.
class CompleteJobInfo {
  CompleteJobInfo({
    required this.totals,
    required this.customerName,
    required this.statusName,
    this.quoteNumber,
    this.quoteId,
  });

  final JobTotals totals;
  final String customerName;
  final String statusName;
  final String? quoteNumber;
  final int? quoteId;
}
