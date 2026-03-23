import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/format.dart';
import '../../dialog/hmb_comfirm_delete_dialog.dart';
import '../../dialog/hmb_dialog.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../../widgets/widgets.g.dart';

class JobActivityTimelineSection extends StatefulWidget {
  final Job job;

  const JobActivityTimelineSection({required this.job, super.key});

  @override
  State<JobActivityTimelineSection> createState() =>
      _JobActivityTimelineSectionState();
}

class _JobActivityTimelineSectionState
    extends State<JobActivityTimelineSection> {
  var _version = 0;

  Future<_ActivityTimelineData> _load() async {
    final activities = await DaoActivity().getByJob(widget.job.id, limit: 200);
    final todoIds = activities
        .map((e) => e.linkedTodoId)
        .whereType<int>()
        .toSet()
        .toList();
    final todos = await DaoToDo().getByIds(todoIds);
    final todoById = {for (final todo in todos) todo.id: todo};
    return _ActivityTimelineData(activities, todoById);
  }

  Future<void> _addActivity() async {
    final result = await showDialog<_ActivityDraft>(
      context: context,
      builder: (_) => const _ActivityEditorDialog(),
    );
    if (result == null) {
      return;
    }

    final activity = Activity.forInsert(
      jobId: widget.job.id,
      type: result.type,
      summary: result.summary.trim(),
      details: result.details?.trim().isEmpty ?? true
          ? null
          : result.details?.trim(),
      occurredAt: result.occurredAt,
    );
    final id = await DaoActivity().insert(activity);
    if (result.createTodo) {
      final todoId = await DaoToDo().insert(
        ToDo.forInsert(
          title: result.summary.trim(),
          note: result.details,
          parentType: ToDoParentType.job,
          parentId: widget.job.id,
        ),
      );
      await DaoActivity().linkTodo(activityId: id, todoId: todoId);
    }
    if (!mounted) {
      return;
    }
    setState(() => _version++);
  }

  Future<void> _editActivity(Activity activity) async {
    final result = await showDialog<_ActivityDraft>(
      context: context,
      builder: (_) => _ActivityEditorDialog(activity: activity),
    );
    if (result == null) {
      return;
    }
    await DaoActivity().update(
      activity.copyWith(
        type: result.type,
        summary: result.summary.trim(),
        details: result.details?.trim().isEmpty ?? true
            ? null
            : result.details?.trim(),
        occurredAt: result.occurredAt,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _version++);
  }

  Future<void> _deleteActivity(Activity activity) async {
    await showConfirmDeleteDialog(
      context: context,
      nameSingular: 'activity',
      question: 'Delete activity "${activity.summary}"?',
      onConfirmed: () async {
        await DaoActivity().delete(activity.id);
        if (!mounted) {
          return;
        }
        setState(() => _version++);
      },
    );
  }

  Future<void> _createFollowupTodo(Activity activity) async {
    final todoId = await DaoToDo().insert(
      ToDo.forInsert(
        title: activity.summary,
        note: activity.details,
        parentType: ToDoParentType.job,
        parentId: widget.job.id,
      ),
    );
    await DaoActivity().linkTodo(activityId: activity.id, todoId: todoId);
    if (!mounted) {
      return;
    }
    setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) => Surface(
    rounded: true,
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: HMBTextHeadline2('Activity Timeline')),
            HMBButton.small(
              label: 'Add Activity',
              hint: 'Add a job activity',
              onPressed: _addActivity,
            ),
          ],
        ),
        FutureBuilderEx<_ActivityTimelineData>(
          key: ValueKey(_version),
          future: _load(),
          builder: (context, data) {
            final timeline = data!;
            if (timeline.activities.isEmpty) {
              return const Text('No activity yet.');
            }

            return HMBColumn(
              children: timeline.activities
                  .map((activity) => _buildItem(activity, timeline.todoById))
                  .toList(),
            );
          },
        ),
      ],
    ),
  );

  Widget _buildItem(Activity activity, Map<int, ToDo> todoById) {
    final todo = activity.linkedTodoId == null
        ? null
        : todoById[activity.linkedTodoId];

    return Surface(
      rounded: true,
      elevation: SurfaceElevation.e1,
      margin: const EdgeInsets.only(top: 8),
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: HMBTextHeadline2(activity.summary)),
              PopupMenuButton<String>(
                onSelected: (action) async {
                  switch (action) {
                    case 'todo':
                      await _createFollowupTodo(activity);
                    case 'edit':
                      await _editActivity(activity);
                    case 'delete':
                      await _deleteActivity(activity);
                  }
                },
                itemBuilder: (context) => [
                  if (activity.linkedTodoId == null)
                    const PopupMenuItem(
                      value: 'todo',
                      child: Text('Create follow-up To Do'),
                    ),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          Text(
            '${_labelForType(activity.type)}'
            '  •  ${activity.source.name}'
            '  •  ${formatDateTime(activity.occurredAt)}',
          ),
          if ((activity.details ?? '').trim().isNotEmpty)
            Text(activity.details!.trim()),
          if (todo != null)
            Text(
              'Follow-up To Do: ${todo.status.name} (${todo.title})',
              style: const TextStyle(color: Colors.orange),
            ),
        ],
      ),
    );
  }

  String _labelForType(ActivityType type) => switch (type) {
    ActivityType.call => 'Call',
    ActivityType.email => 'Email',
    ActivityType.sms => 'SMS',
    ActivityType.visit => 'Visit',
    ActivityType.quoteFollowUp => 'Quote Follow-up',
    ActivityType.scheduleUpdate => 'Schedule Update',
    ActivityType.note => 'Note',
    ActivityType.workDay => 'Worked On Job',
  };
}

class _ActivityTimelineData {
  final List<Activity> activities;
  final Map<int, ToDo> todoById;

  _ActivityTimelineData(this.activities, this.todoById);
}

enum _ActivityTemplate {
  custom,
  followedUpQuote,
  scheduledVisit,
  calledCustomer,
  sentInvoiceReminder,
}

class _ActivityDraft {
  final DateTime occurredAt;
  final ActivityType type;
  final String summary;
  final String? details;
  final bool createTodo;

  const _ActivityDraft({
    required this.occurredAt,
    required this.type,
    required this.summary,
    required this.details,
    required this.createTodo,
  });
}

class _ActivityEditorDialog extends StatefulWidget {
  final Activity? activity;

  const _ActivityEditorDialog({this.activity});

  @override
  State<_ActivityEditorDialog> createState() => _ActivityEditorDialogState();
}

class _ActivityEditorDialogState extends State<_ActivityEditorDialog> {
  late final TextEditingController _summaryController;
  late final TextEditingController _detailsController;
  late ActivityType _type;
  late DateTime _occurredAt;
  var _createTodo = false;
  var _template = _ActivityTemplate.custom;
  String? _error;

  bool get _editing => widget.activity != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.activity;
    _type = existing?.type ?? ActivityType.note;
    _occurredAt = existing?.occurredAt ?? DateTime.now();
    _summaryController = TextEditingController(text: existing?.summary ?? '');
    _detailsController = TextEditingController(text: existing?.details ?? '');
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _applyTemplate(_ActivityTemplate template) {
    switch (template) {
      case _ActivityTemplate.custom:
        return;
      case _ActivityTemplate.followedUpQuote:
        _type = ActivityType.quoteFollowUp;
        _summaryController.text = 'Followed up on quote';
      case _ActivityTemplate.scheduledVisit:
        _type = ActivityType.scheduleUpdate;
        _summaryController.text = 'Scheduled visit';
      case _ActivityTemplate.calledCustomer:
        _type = ActivityType.call;
        _summaryController.text = 'Called customer';
      case _ActivityTemplate.sentInvoiceReminder:
        _type = ActivityType.email;
        _summaryController.text = 'Sent invoice reminder';
    }
  }

  void _save() {
    final summary = _summaryController.text.trim();
    if (summary.isEmpty) {
      setState(() {
        _error = 'Summary is required.';
      });
      return;
    }
    Navigator.of(context).pop(
      _ActivityDraft(
        occurredAt: _occurredAt,
        type: _type,
        summary: summary,
        details: _detailsController.text,
        createTodo: !_editing && _createTodo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => HMBDialog(
    title: Text(_editing ? 'Edit Activity' : 'Add Activity'),
    content: HMBColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_editing)
          DropdownButtonFormField<_ActivityTemplate>(
            initialValue: _template,
            decoration: const InputDecoration(labelText: 'Template'),
            items: const [
              DropdownMenuItem(
                value: _ActivityTemplate.custom,
                child: Text('Custom'),
              ),
              DropdownMenuItem(
                value: _ActivityTemplate.followedUpQuote,
                child: Text('Followed up on quote'),
              ),
              DropdownMenuItem(
                value: _ActivityTemplate.scheduledVisit,
                child: Text('Scheduled visit'),
              ),
              DropdownMenuItem(
                value: _ActivityTemplate.calledCustomer,
                child: Text('Called customer'),
              ),
              DropdownMenuItem(
                value: _ActivityTemplate.sentInvoiceReminder,
                child: Text('Sent invoice reminder'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _template = value;
                _applyTemplate(value);
              });
            },
          ),
        DropdownButtonFormField<ActivityType>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: ActivityType.values
              .where((e) => e != ActivityType.workDay)
              .map(
                (type) => DropdownMenuItem(value: type, child: Text(type.name)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _type = value;
            });
          },
        ),
        TextFormField(
          controller: _summaryController,
          decoration: const InputDecoration(labelText: 'Summary'),
        ),
        TextFormField(
          controller: _detailsController,
          decoration: const InputDecoration(labelText: 'Details'),
          maxLines: 3,
        ),
        if (!_editing)
          CheckboxListTile(
            value: _createTodo,
            onChanged: (value) => setState(() => _createTodo = value ?? false),
            title: const Text('Create follow-up To Do'),
            contentPadding: EdgeInsets.zero,
          ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      ],
    ),
    actions: [
      HMBButton(
        label: 'Cancel',
        hint: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
      HMBButton(label: 'Save', hint: 'Save activity', onPressed: _save),
    ],
  );
}
