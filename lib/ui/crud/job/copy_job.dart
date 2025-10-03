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
import '../../../util/dart/list_ex.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';

/// Result returned from the move dialog
class MoveTasksResult {
  final List<Task> selectedTasks;

  final String summary;

  MoveTasksResult({required this.selectedTasks, required this.summary});
}

/// Launch the “Copy Job & Move Tasks” dialog
Future<MoveTasksResult?> selectTasksToMoveAndDescribeJob({
  required BuildContext context,
  required Job job,
}) async {
  if (!context.mounted) {
    return null;
  }

  return showDialog<MoveTasksResult>(
    context: context,
    builder: (_) => DialogMoveTasksToNewJob(job: job),
  );
}

/// Internal model for rendering each task’s movability
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

class DialogMoveTasksToNewJob extends StatefulWidget {
  final Job job;

  const DialogMoveTasksToNewJob({required this.job, super.key});

  @override
  State<DialogMoveTasksToNewJob> createState() =>
      _DialogMoveTasksToNewJobState();
}

class _DialogMoveTasksToNewJobState
    extends DeferredState<DialogMoveTasksToNewJob> {
  final Map<Task, bool> _selected = {};
  final _summaryController = TextEditingController();

  List<MovableTaskInfo> _rows = [];
  var _selectAll = true;
  var _loading = true;

  @override
  Future<void> asyncInitState() async {
    _summaryController.text = widget.job.summary;

    // Load tasks for the job
    final tasks = await DaoTask().getTasksByJob(widget.job.id);

    // Preload bits used by validation
    final billingType = widget.job.billingType;
    final quotes = billingType == BillingType.fixedPrice
        ? await DaoQuote().getByJobId(widget.job.id)
        : <Quote>[];
    final approvedQuotes = quotes.where((q) => q.state.isPostApproval).toList();

    _rows = [];
    for (final t in tasks) {
      final reason = await _validateTaskMovable(
        job: widget.job,
        task: t,
        approvedQuotes: approvedQuotes,
      );
      final movable = reason == null;
      _rows.add(
        MovableTaskInfo(task: t, movable: movable, reasonIfBlocked: reason),
      );
      if (movable) {
        _selected[t] = true; // default select movable ones
      }
    }
    _selectAll =
        _selected.values.isNotEmpty && _selected.values.every((v) => v);
    _loading = false;
    setState(() {});
  }

  Future<String?> _validateTaskMovable({
    required Job job,
    required Task task,
    required List<Quote> approvedQuotes,
  }) async {
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

    // 3) locked by approved fixed-price quote unless the group is rejected
    if (job.billingType == BillingType.fixedPrice &&
        approvedQuotes.isNotEmpty) {
      for (final q in approvedQuotes) {
        final groups = await DaoQuoteLineGroup().getByQuoteId(q.id);
        final g = groups.firstWhereOrNull((g) => g.taskId == task.id);
        if (g != null && g.lineApprovalStatus != LineApprovalStatus.rejected) {
          return 'Task is in an approved fixed-price quote.';
        }
      }
    }

    return null; // movable
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('''Copy Job & Move Tasks: ${widget.job.summary}'''),
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
              const Text('New Summary'),
              TextField(
                controller: _summaryController,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter summary for the new job',
                ),
              ),
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
                } else {
                  return ListTile(
                    title: Text(row.task.name),
                    subtitle: Text(
                      row.reasonIfBlocked ?? 'Not movable',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    trailing: const Icon(Icons.block, color: Colors.redAccent),
                  );
                }
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
        hint: "Don't copy the Job",
      ),
      HMBButton(
        label: 'Create & Move',
        hint: 'Create new job and move selected tasks',
        onPressed: () {
          final selected = _selected.entries
              .where((e) => e.value)
              .map((e) => e.key)
              .toList();
          if (selected.isEmpty) {
            HMBToast.error('Please select at least one task to move.');
            return;
          }
          Navigator.of(context).pop(
            MoveTasksResult(
              selectedTasks: selected,
              summary: _summaryController.text.trim(),
            ),
          );
        },
      ),
    ],
  );
}
