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

import 'dart:async';

import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';
import 'package:strings/strings.dart';

import '../../../api/chat_gpt/job_assist_api_client.dart';
import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/log.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';
import '../base_full_screen/list_entity_screen.dart';
import '../base_nested/list_nested_screen.dart';
import 'edit_task_screen.dart';
import 'list_task_card.dart';
import 'task_instructions_screen.dart';

class TaskListScreen extends StatefulWidget {
  final Parent<Job> parent;
  final bool extended;
  final AnalyzeTaskInstructions? analyzeInstructions;
  final SaveTaskInstructions? saveInstructions;
  final void Function(int count)? onInstructionsSaved;

  const TaskListScreen({
    required this.parent,
    required this.extended,
    this.analyzeInstructions,
    this.saveInstructions,
    this.onInstructionsSaved,
    super.key,
  });

  @override
  // ignore: library_private_types_in_public_api
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  var _listKey = GlobalKey<EntityListScreenState<Task>>();

  /// If a time is running for a task, this will be the
  /// active TimeEntry record.
  /// Only a single task can have a time running at a time.
  late Future<TimeEntry?> activeTimeEntry;

  @override
  void initState() {
    activeTimeEntry = DaoTimeEntry().getActiveEntry();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.parent.parent!;
    final showCompleted = June.getState(
      ShowInActiveTasksState.new,
    )._showInActiveTasks;
    return HMBColumn(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!job.isStock)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: HMBButton.smallWithIcon(
                label: 'Add from Instructions',
                icon: const Icon(Icons.auto_awesome),
                hint: 'Use customer email or SMS instructions to propose tasks',
                onPressed: _addFromInstructions,
              ),
            ),
          ),
        Flexible(
          child: EntityListScreen<Task>(
            entityNameSingular: 'Task',
            entityNamePlural: 'Tasks',
            key: _listKey,
            dao: DaoTask(),
            fetchList: _fetchTasks,
            listCardTitle: (entity) => Text(entity.name),

            /// all filter modes exclude some data.
            isFilterActive: () => true,
            filterSheetBuilder: (entity) => Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                HMBToggle(
                  label: 'Show Inactive',
                  hint: showCompleted
                      ? 'Show Only Active Tasks'
                      : 'Show Inactive Tasks',
                  initialValue: June.getState(
                    ShowInActiveTasksState.new,
                  )._showInActiveTasks,
                  onToggled: (value) {
                    setState(() {
                      June.getState(ShowInActiveTasksState.new).toggle();
                      _listKey = GlobalKey<EntityListScreenState<Task>>();
                    });
                  },
                ),
              ],
            ),
            onEdit: (task) =>
                TaskEditScreen(job: widget.parent.parent!, task: task),
            onDelete: onDelete,
            canEdit: (_) => !widget.parent.parent!.isStock,
            canDelete: (_) => !widget.parent.parent!.isStock,

            cardHeight: null,
            listCard: _buildFullTasksDetails,
            // : _buildTaskSummary(task),
          ),
        ),
      ],
    );
  }

  Future<void> _addFromInstructions() async {
    final job = widget.parent.parent!;
    final count = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => TaskInstructionsScreen(
          job: job,
          analyze: widget.analyzeInstructions ?? _analyzeInstructions,
          save: widget.saveInstructions ?? _saveInstructions,
        ),
      ),
    );
    if (!mounted || count == null) {
      return;
    }
    await _listKey.currentState?.refresh(scrollToTop: true);
    final onInstructionsSaved = widget.onInstructionsSaved;
    if (onInstructionsSaved != null) {
      onInstructionsSaved(count);
    } else {
      HMBToast.info('Added $count ${count == 1 ? 'task' : 'tasks'}.');
    }
  }

  Future<List<TaskInstructionDraft>> _analyzeInstructions(
    String instructions,
  ) async {
    final job = widget.parent.parent!;
    final existingTasks = await DaoTask().getTasksByJob(job.id);
    final suggestions = await JobAssistApiClient()
        .analyzeAdditionalInstructions(
          instructions: instructions,
          jobSummary: job.summary,
          jobDescription: job.description,
          existingTasks: existingTasks
              .map((task) => '${task.name}: ${task.description}')
              .toList(),
        );
    if (suggestions == null) {
      throw StateError(
        'AI task suggestions require an OpenAI API key in '
        'Settings | Integrations | ChatGPT.',
      );
    }
    return suggestions
        .map(
          (suggestion) => TaskInstructionDraft(
            name: suggestion.name,
            description: suggestion.description,
          ),
        )
        .toList();
  }

  Future<int> _saveInstructions(List<TaskInstructionDraft> drafts) {
    final job = widget.parent.parent!;
    return saveTaskInstructionDrafts(jobId: job.id, drafts: drafts);
  }

  Future<bool> onDelete(Task task) async {
    if (widget.parent.parent!.isStock) {
      HMBToast.error('The Stock task cannot be deleted.');
      return false;
    }

    // assigned tasks cannot be deleted.
    final taskAssignments = await DaoWorkAssignmentTask().getByTask(task);
    if (taskAssignments.isNotEmpty) {
      HMBToast.error(
        'Task cannot be deleted while it is assigned to a Work Assignment.',
      );
      return false;
    }

    await DaoTask().delete(task.id);
    return true;
  }

  Future<List<Task>> _fetchTasks(String? filter) async {
    final showInactive = June.getState(
      ShowInActiveTasksState.new,
    )._showInActiveTasks;
    final search = filter?.trim().toLowerCase();
    final tasks = await DaoTask().getTasksByJob(widget.parent.parent!.id);

    final included = <Task>[];
    for (final task in tasks) {
      final status = task.status;
      final intActive = status.isInActive();
      final matchesSearch =
          Strings.isBlank(search) ||
          task.name.toLowerCase().contains(search!) ||
          task.description.toLowerCase().contains(search) ||
          task.assumption.toLowerCase().contains(search);
      if ((showInactive && intActive) || (!showInactive && !intActive)) {
        if (matchesSearch) {
          included.add(task);
        }
      }
    }
    return included;
  }

  Future<void> _timerStarted() async {
    try {
      await BlockingUI().runAndWait(() async {
        await _listKey.currentState?.refresh(scrollToTop: true);
      });
    } catch (error, stackTrace) {
      Log.e(
        'Could not refresh tasks after starting timer',
        error: error,
        stackTrace: stackTrace,
      );
      HMBToast.error('The timer started, but the task list could not refresh.');
    }
  }

  Widget _buildFullTasksDetails(Task task) => ListTaskCard(
    key: ValueKey(task.id),
    job: widget.parent.parent!,
    task: task,
    summary: false,
    onTimerStarted: () => unawaited(_timerStarted()),
  );
}

Future<int> saveTaskInstructionDrafts({
  required int jobId,
  required List<TaskInstructionDraft> drafts,
}) {
  final tasks = drafts.where((draft) => draft.name.trim().isNotEmpty).toList();
  if (tasks.isEmpty) {
    return Future.value(0);
  }

  return DatabaseHelper.instance.database.transaction((transaction) async {
    for (final draft in tasks) {
      await DaoTask().insert(
        Task.forInsert(
          jobId: jobId,
          name: draft.name.trim(),
          description: draft.description.trim(),
          status: TaskStatus.awaitingApproval,
        ),
        transaction,
      );
    }
    return tasks.length;
  });
}

class ShowInActiveTasksState extends JuneState {
  var _showInActiveTasks = false;

  void toggle() {
    _showInActiveTasks = !_showInActiveTasks;
    setState(); // Notify listeners to rebuild
  }
}
