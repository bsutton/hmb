/*
 Copyright © OnePub IP Pty Ltd...
*/

/*
 Copyright © OnePub IP Pty Ltd...
*/

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';

/// Result returned from the move dialog
class MoveTasksResult {
  final List<Task> selectedTasks;
  final String summary;
  final int? destinationJobId;

  MoveTasksResult({
    required this.selectedTasks,
    required this.summary,
    this.destinationJobId,
  });

  bool get createsNewJob => destinationJobId == null;
}

/// Launch the task move dialog.
Future<MoveTasksResult?> selectTasksToMoveAndDescribeJob({
  required BuildContext context,
  required Job job,
}) async {
  if (!context.mounted) {
    return null;
  }

  return showDialog<MoveTasksResult>(
    context: context,
    builder: (_) => DialogMoveTasks(job: job),
  );
}

/// Internal model for rendering each task's movability
class MovableTaskInfo {
  final Task task;
  final bool movable;
  final String? reasonIfBlocked;

  MovableTaskInfo({
    required this.task,
    required this.movable,
    this.reasonIfBlocked,
  });
}

enum MoveDestination { newJob, existingJob }

class DialogMoveTasks extends StatefulWidget {
  final Job job;

  const DialogMoveTasks({required this.job, super.key});

  @override
  State<DialogMoveTasks> createState() => _DialogMoveTasksState();
}

class _DialogMoveTasksState extends DeferredState<DialogMoveTasks> {
  final Map<Task, bool> _selected = {};
  final _summaryController = TextEditingController();

  List<MovableTaskInfo> _rows = [];
  List<Job> _candidateJobs = [];
  var _selectAll = false;
  var _loading = true;
  var _showAllCustomers = false;
  MoveDestination _destination = MoveDestination.newJob;
  Job? _selectedTargetJob;

  @override
  Future<void> asyncInitState() async {
    _summaryController.text = widget.job.summary;

    // Load tasks for the job
    final tasks = await DaoTask().getTasksByJob(widget.job.id);

    _rows = [];
    for (final t in tasks) {
      final reason = await _validateTaskMovable(task: t);
      final movable = reason == null;
      _rows.add(
        MovableTaskInfo(task: t, movable: movable, reasonIfBlocked: reason),
      );
      if (movable) {
        _selected[t] = false;
      }
    }

    await _loadCandidateJobs();
    _selectAll = false;
    _loading = false;
    setState(() {});
  }

  Future<void> _loadCandidateJobs() async {
    final jobs = await DaoJob().getActiveJobs(null);
    _candidateJobs = jobs.where((candidate) {
      if (candidate.id == widget.job.id) {
        return false;
      }
      if (_showAllCustomers) {
        return true;
      }
      return candidate.customerId == widget.job.customerId;
    }).toList()..sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));

    if (_selectedTargetJob != null &&
        !_candidateJobs.any((j) => j.id == _selectedTargetJob!.id)) {
      _selectedTargetJob = null;
    }
  }

  Future<String?> _validateTaskMovable({required Task task}) async {
    // 1) billed?
    final items = await DaoTaskItem().getByTask(task.id);
    if (items.any((i) => i.billed || i.invoiceLineId != null)) {
      return 'Task has billed items.';
    }
    final time = await DaoTimeEntry().getByTask(task.id);
    if (time.any((te) => te.billed || te.invoiceLineId != null)) {
      return 'Task has billed time.';
    }

    // 2) has work assignment?
    final wat = await DaoWorkAssignmentTask().getByTask(task);
    if (wat.isNotEmpty) {
      return 'Task is linked to a work assignment.';
    }

    // 3) linked to quote
    if (await DaoTask().isTaskLinkedToQuote(task)) {
      return 'Task is linked to a quote.';
    }

    return null;
  }

  void _toggleSelectAll(bool? v) {
    setState(() {
      _selectAll = v ?? false;
      for (final row in _rows.where((r) => r.movable)) {
        _selected[row.task] = _selectAll;
      }
    });
  }

  void _toggleOne(Task task, bool? v) {
    setState(() {
      _selected[task] = v ?? false;
      final moveableTasks = _rows
          .where((r) => r.movable)
          .map((r) => r.task)
          .toList();
      if (moveableTasks.isEmpty) {
        _selectAll = false;
      } else {
        _selectAll = moveableTasks.every((task) => _selected[task] ?? false);
      }
    });
  }

  Future<bool> _confirmCrossCustomerMove() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Different Customer'),
        content: const Text(
          'The destination job belongs to a different customer. '
          'Do you still want to move these tasks?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('''Move Tasks: ${widget.job.summary}'''),
    content: DeferredBuilder(
      this,
      builder: (_) {
        if (_loading) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final movableCount = _rows.where((r) => r.movable).length;
        final selectedCount = _selected.entries.where((e) => e.value).length;

        return SingleChildScrollView(
          child: HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioListTile<MoveDestination>(
                title: const Text('Create new job and move tasks'),
                value: MoveDestination.newJob,
                groupValue: _destination,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _destination = value;
                  });
                },
              ),
              RadioListTile<MoveDestination>(
                title: const Text('Move tasks to existing job'),
                value: MoveDestination.existingJob,
                groupValue: _destination,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _destination = value;
                  });
                },
              ),
              if (_destination == MoveDestination.newJob) ...[
                const Text('New Summary'),
                TextField(
                  controller: _summaryController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter summary for the new job',
                  ),
                ),
              ],
              if (_destination == MoveDestination.existingJob) ...[
                SwitchListTile(
                  title: const Text('Show jobs for all customers'),
                  value: _showAllCustomers,
                  onChanged: (value) async {
                    _showAllCustomers = value;
                    await _loadCandidateJobs();
                    setState(() {});
                  },
                ),
                DropdownButtonFormField<Job>(
                  value: _selectedTargetJob,
                  decoration: const InputDecoration(
                    labelText: 'Destination Job',
                  ),
                  items: _candidateJobs
                      .map(
                        (job) => DropdownMenuItem<Job>(
                          value: job,
                          child: Text('Job #${job.id} ${job.summary}'),
                        ),
                      )
                      .toList(),
                  onChanged: (job) {
                    setState(() {
                      _selectedTargetJob = job;
                    });
                  },
                ),
                if (_candidateJobs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No destination jobs available for this selection.',
                    ),
                  ),
              ],
              if (movableCount > 0)
                CheckboxListTile(
                  title: Text('Select All ($selectedCount / $movableCount)'),
                  value: _selectAll,
                  onChanged: _toggleSelectAll,
                ),
              ..._rows.map((row) {
                if (row.movable) {
                  return CheckboxListTile(
                    title: Text(row.task.name),
                    subtitle: Text('Task #${row.task.id}'),
                    value: _selected[row.task] ?? false,
                    onChanged: (v) => _toggleOne(row.task, v),
                  );
                }
                return ListTile(
                  title: Text(row.task.name),
                  subtitle: Text(
                    row.reasonIfBlocked ?? 'Not movable',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  trailing: const Icon(Icons.block, color: Colors.redAccent),
                );
              }),
            ],
          ),
        );
      },
    ),
    actions: [
      HMBButton(
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
        hint: "Don't move any tasks",
      ),
      HMBButton(
        label: _destination == MoveDestination.newJob
            ? 'Create & Move'
            : 'Move',
        hint: _destination == MoveDestination.newJob
            ? 'Create new job and move selected tasks'
            : 'Move selected tasks to destination job',
        onPressed: () async {
          final selected = _selected.entries
              .where((e) => e.value)
              .map((e) => e.key)
              .toList();
          if (selected.isEmpty) {
            HMBToast.error('Please select at least one task to move.');
            return;
          }

          if (_destination == MoveDestination.existingJob) {
            if (_selectedTargetJob == null) {
              HMBToast.error('Please select a destination job.');
              return;
            }

            if (_selectedTargetJob!.customerId != widget.job.customerId) {
              final proceed = await _confirmCrossCustomerMove();
              if (!proceed) {
                return;
              }
            }

            if (!context.mounted) {
              return;
            }

            Navigator.of(context).pop(
              MoveTasksResult(
                selectedTasks: selected,
                summary: '',
                destinationJobId: _selectedTargetJob!.id,
              ),
            );
            return;
          }

          final summary = _summaryController.text.trim();
          Navigator.of(context).pop(
            MoveTasksResult(
              selectedTasks: selected,
              summary: summary.isEmpty ? widget.job.summary : summary,
            ),
          );
        },
      ),
    ],
  );
}
