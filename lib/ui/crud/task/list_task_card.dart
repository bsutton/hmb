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

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/flutter/flutter_util.g.dart';
import '../../widgets/hmb_start_time_entry.dart';
import '../../widgets/layout/layout.g.dart';
import '../job/edit_job_card.dart';

class ListTaskCard extends StatefulWidget {
  final Job job;
  final Task task;
  final bool summary;

  const ListTaskCard({
    required this.job,
    required this.task,
    required this.summary,
    super.key,
  });

  @override
  State<ListTaskCard> createState() => _ListTaskCardState();
}

class _ListTaskCardState extends State<ListTaskCard> {
  late Task activeTask;

  @override
  void didUpdateWidget(covariant ListTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    activeTask = widget.task;
  }

  @override
  void initState() {
    super.initState();
    activeTask = widget.task;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.summary) {
      return _buildTaskSummary(activeTask);
    } else {
      return _buildFullTaskDetails();
    }
  }

  Widget _buildFullTaskDetails() => HMBColumn(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(activeTask.status.name),
      FutureBuilderEx(
        future: DaoTask().getAccruedValueForTask(
          job: widget.job,
          task: activeTask,
          includeBilled: true,
        ),
        builder: (context, taskAccruedValue) {
          final accrued = taskAccruedValue!;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Earned (Hrs|\$): ${accrued.earnedLabourHours.format('0.00')}h'
              ' | ${accrued.earnedMaterialCharges}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
      FutureBuilderEx<String?>(
        future: _getAssignmentSummary(activeTask.id),
        builder: (context, assignmentSummary) => assignmentSummary == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  assignmentSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
      ),
      HMBStartTimeEntry(
        key: ValueKey(activeTask),
        task: activeTask,
        onTimerChanged: () => setState(() {}),
        onStart: (job, task) {
          June.getState(SelectJobStatus.new).jobStatus = job.status;
          activeTask = task;
          setState(() {});
        },
      ),
    ],
  );

  Widget _buildTaskSummary(Task task) => HMBColumn(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(task.status.name),
      FutureBuilderEx(
        future: DaoTimeEntry().getByTask(task.id),
        builder: (context, timeEntries) => Text(
          formatDuration(
            timeEntries!.fold<Duration>(
              Duration.zero,
              (a, b) => a + b.duration,
            ),
          ),
        ),
      ),
      FutureBuilderEx<int>(
        future: _getPhotoCount(task.id),
        builder: (context, photoCount) => Text('Photos: ${photoCount ?? 0}'),
      ), // Display photo count
      FutureBuilderEx<String?>(
        future: _getAssignmentSummary(task.id),
        builder: (context, assignmentSummary) => assignmentSummary == null
            ? const SizedBox.shrink()
            : Text(
                assignmentSummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
      HMBStartTimeEntry(
        task: task,
        onStart: (job, task) {
          June.getState(SelectJobStatus.new).jobStatus = job.status;
          activeTask = task;
          setState(() {});
        },
      ),
    ],
  );

  Future<int> _getPhotoCount(int taskId) async =>
      (await DaoPhoto().getByParent(taskId, ParentType.task)).length;

  Future<String?> _getAssignmentSummary(int taskId) async {
    final supplierNames = await DaoWorkAssignmentTask()
        .getSupplierNamesByTaskId(taskId);
    if (supplierNames.isEmpty) {
      return null;
    }
    return 'Assigned to: ${supplierNames.join(', ')}';
  }
}
