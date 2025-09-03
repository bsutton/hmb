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
import '../../widgets/text/hmb_text.dart';
import '../job/edit_job_card.dart';

class ListTaskCard extends StatefulWidget {
  final Task task;
  final bool summary;

  const ListTaskCard({required this.task, required this.summary, super.key});

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

  Column _buildFullTaskDetails() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(activeTask.status.name),
      FutureBuilderEx(
        future: DaoTask()
            // ignore: discarded_futures
            .getAccruedValueForTask(task: activeTask, includeBilled: true),
        builder: (context, taskAccruedValue) => Row(
          children: [
            HMBText(
              'Effort(hrs): ${taskAccruedValue!.earnedLabourHours.format('0.00')}/${taskAccruedValue.taskEstimatedValue.estimatedLabourHours.format('0.00')}',
            ),
            HMBText(
              ' Earnings: ${taskAccruedValue.earnedMaterialCharges}/${taskAccruedValue.taskEstimatedValue.estimatedMaterialsCharge}',
            ),
          ],
        ),
      ),
      HMBStartTimeEntry(
        key: ValueKey(activeTask),
        task: activeTask,
        onStart: (job, task) {
          June.getState(SelectJobStatus.new).jobStatus = job.status;
          activeTask = task;
          setState(() {});
        },
      ),
    ],
  );

  Column _buildTaskSummary(Task task) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(task.status.name),
      FutureBuilderEx(
        // ignore: discarded_futures
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
        // ignore: discarded_futures
        future: _getPhotoCount(task.id),
        builder: (context, photoCount) => Text('Photos: ${photoCount ?? 0}'),
      ), // Display photo count
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
}
