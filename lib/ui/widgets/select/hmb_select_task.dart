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
import 'package:june/june.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import 'hmb_droplist.dart';

/// Allows the user to select a Primary Site from the sites
/// owned by a customer and associate them with another
/// entity e.g. a job.
class HMBSelectTask extends StatefulWidget {
  /// The customer that owns the site.
  final Job? job;
  final SelectedTask selectedTask;
  final void Function(Task? task)? onSelected;
  final bool required;

  const HMBSelectTask({
    required this.selectedTask,
    required this.job,
    super.key,
    this.onSelected,
    this.required = false,
  });

  @override
  HMBSelectTaskState createState() => HMBSelectTaskState();
}

class HMBSelectTaskState extends State<HMBSelectTask> {
  Future<Task?> _getInitialTask() =>
      DaoTask().getById(widget.selectedTask.taskId);

  void _onTaskChanged(Task? newValue) {
    setState(() {
      widget.selectedTask.taskId = newValue?.id;
    });
    widget.onSelected?.call(newValue);
  }

  @override
  Widget build(BuildContext context) => JuneBuilder(
    () => widget.selectedTask,
    id: widget.selectedTask,
    builder: (state) {
      if (widget.job == null) {
        return const Center(child: Text('Tasks: Select a Job first.'));
      } else {
        return Row(
          children: [
            Expanded(
              child: HMBDroplist<Task>(
                key: ValueKey(widget.selectedTask.taskId),
                title: 'Task',
                selectedItem: _getInitialTask,
                items: (filter) => DaoTask().getTasksByJob(widget.job!.id),
                format: (task) => task.name,
                onChanged: _onTaskChanged,
                required: widget.required,
              ),
            ),
          ],
        );
      }
    },
  );
}

class SelectedTask extends JuneState {
  int? _taskId;

  SelectedTask();

  int? get taskId => _taskId;

  set taskId(int? value) {
    _taskId = value;
    setState([this]);
  }
}
