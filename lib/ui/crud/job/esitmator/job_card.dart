import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../../../dao/_index.g.dart';
import '../../../../dao/dao_task_item.dart';
import '../../../../entity/job.dart';
import '../../../../entity/task_item_type.dart';
import '../../../../util/money_ex.dart';
import '../../../invoicing/dialog_select_tasks.dart';
import '../../../invoicing/select_job_dialog.dart';
import '../../../widgets/hmb_button.dart';
import '../../../widgets/hmb_toast.dart';
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
          final labourCost = info!.totals.labourCost;
          final materialsCost = info.totals.materialsCost;
          final combinedCost = labourCost + materialsCost;

          return Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.job.summary,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Customer: ${info.customerName}'),
                  Text('Job Number: ${widget.job.id}'),
                  Text('Status: ${info.statusName}'),
                  const SizedBox(height: 16),
                  Text('Labour: $labourCost'),
                  Text('Materials: $materialsCost'),
                  Text('Combined: $combinedCost'),
                  const SizedBox(height: 16),
                  HMBButton(
                    label: 'Update Estimates',
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => JobEstimateBuilderScreen(
                            job: widget.job,
                          ),
                        ),
                      );
                      // After returning, call onEstimatesUpdated to refresh
                      widget.onEstimatesUpdated();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );

  Future<void> _createQuote() async {
    final job = await showDialog<Job?>(
      context: context,
      builder: (context) => const SelectJobDialog(),
    );

    if (job == null) {
      return;
    }

    final invoiceOptions = await showQuote(context: context, job: job);

    if (invoiceOptions != null) {
      try {
        if (!invoiceOptions.billBookingFee &&
            invoiceOptions.selectedTaskIds.isEmpty) {
          HMBToast.error('You must select a task or the booking Fee',
              acknowledgmentRequired: true);
          return;
        }
        await DaoQuote().create(job, invoiceOptions);
        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        HMBToast.error('Failed to create quote: $e',
            acknowledgmentRequired: true);
      }
    }
  }

  Future<CompleteJobInfo> _loadCompleteJobInfo(Job job) async {
    final totals = await _loadJobTotals(job);
    final customer = job.customerId != null
        ? await DaoCustomer().getById(job.customerId)
        : null;
    final jobStatus = job.jobStatusId != null
        ? await DaoJobStatus().getById(job.jobStatusId)
        : null;

    final customerName = customer?.name ?? 'N/A';
    final statusName = jobStatus?.name ?? 'Unknown';

    return CompleteJobInfo(
      totals: totals,
      customerName: customerName,
      statusName: statusName,
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
        if (item.itemTypeId == TaskItemTypeEnum.labour.id) {
          // Labour cost
          totalLabour += item.calcLabourCost(hourlyRate);
        } else {
          // Material cost
          totalMaterials += item.calcMaterialCost(billingType);
        }
      }
    }

    return JobTotals(labourCost: totalLabour, materialsCost: totalMaterials);
  }
}

/// Holds totals for a job
class JobTotals {
  JobTotals({required this.labourCost, required this.materialsCost});

  final Money labourCost;
  final Money materialsCost;
}

/// Holds all required details for displaying the job card fields.
class CompleteJobInfo {
  CompleteJobInfo({
    required this.totals,
    required this.customerName,
    required this.statusName,
  });

  final JobTotals totals;
  final String customerName;
  final String statusName;
}
