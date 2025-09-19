import 'package:flutter/widgets.dart';
import 'package:strings/strings.dart';

import '../../../entity/job.dart';
import '../../../entity/todo.dart';
import '../../../util/dart/dart.g.dart';
import '../../widgets/fields/fields.g.dart';
import '../../widgets/help_button.dart';
import '../../widgets/hmb_date_time_picker.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/select/select.g.dart';
import '../../widgets/widgets.g.dart' show HMBSelectChips;

class ToDoEditorCard extends StatefulWidget {
  final ToDo todo;
  final Job? preselectedJob;
  final ValueChanged<ToDo> onChanged;

  const ToDoEditorCard({
    required this.todo,
    required this.onChanged,
    this.preselectedJob,
    super.key,
  });

  @override
  State<ToDoEditorCard> createState() => _ToDoEditorCardState();
}

class _ToDoEditorCardState extends State<ToDoEditorCard> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;

  // Local selectors for pickers (only used when needed)
  final _selectedJob = SelectedJob();
  final _selectedCustomer = SelectedCustomer();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.todo.title);
    _noteCtrl = TextEditingController(text: widget.todo.note ?? '');

    // Seed selectors from the entity
    switch (widget.todo.parentType) {
      case ToDoParentType.job:
        _selectedJob.jobId = widget.todo.parentId;
      case ToDoParentType.customer:
        _selectedCustomer.customerId = widget.todo.parentId;
      case null:
        break;
    }
  }

  @override
  void didUpdateWidget(covariant ToDoEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todo.title != widget.todo.title &&
        _titleCtrl.text != widget.todo.title) {
      _titleCtrl.text = widget.todo.title;
    }
    final newNote = widget.todo.note ?? '';
    if ((oldWidget.todo.note ?? '') != newNote && _noteCtrl.text != newNote) {
      _noteCtrl.text = newNote;
    }
  }

  void _emit(ToDo updated) => widget.onChanged(updated);

  @override
  Widget build(BuildContext context) {
    final v = widget.todo;

    return HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title & Notes
        HMBTextField(
          controller: _titleCtrl,
          labelText: 'Title',
          required: true,
          onChanged: (txt) => _emit(v.copyWith(title: txt)),
        ),
        HMBTextArea(
          controller: _noteCtrl,
          labelText: 'Notes',
          onChanged: (txt) =>
              _emit(v.copyWith(note: Strings.trim(txt).isEmpty ? null : txt)),
        ),

        // Context (None / Job / Customer) – hidden if preselectedJob provided
        if (widget.preselectedJob == null)
          HMBSelectChips<ToDoParentType?>(
            label: 'Context',
            value: v.parentType,
            items: const [null, ToDoParentType.job, ToDoParentType.customer],
            format: (x) => x == null ? 'None' : x.name,
            onChanged: (choice) {
              // Reset parentId when context changes
              switch (choice) {
                case ToDoParentType.job:
                  _selectedCustomer.customerId = null;
                  _selectedJob.jobId = null;
                  _emit(v.copyWith(parentType: choice));
                case ToDoParentType.customer:
                  _selectedJob.jobId = null;
                  _selectedCustomer.customerId = null;
                  _emit(v.copyWith(parentType: choice));
                case null:
                  _selectedJob.jobId = null;
                  _selectedCustomer.customerId = null;
                  _emit(v.copyWith());
              }
            },
          ),

        // Job selector
        if (widget.preselectedJob == null && v.parentType == ToDoParentType.job)
          HMBSelectJob(
            selectedJob: _selectedJob,
            required: true,
            onSelected: (job) {
              _selectedJob.jobId = job?.id;
              _emit(
                v.copyWith(parentType: ToDoParentType.job, parentId: job?.id),
              );
            },
          ),

        // Customer selector
        if (widget.preselectedJob == null &&
            v.parentType == ToDoParentType.customer)
          HMBSelectCustomer(
            selectedCustomer: _selectedCustomer,
            required: true,
            onSelected: (c) {
              _selectedCustomer.customerId = c?.id;
              _emit(
                v.copyWith(
                  parentType: ToDoParentType.customer,
                  parentId: c?.id,
                ),
              );
            },
          ),

        // Priority
        HMBSelectChips<ToDoPriority>(
          label: 'Priority',
          value: v.priority,
          items: ToDoPriority.values,
          format: (x) => x.name,
          onChanged: (p) => _emit(v.copyWith(priority: p)),
        ),

        // Due date/time
        HMBDateTimeField(
          label: 'Due By',
          mode: HMBDateTimeFieldMode.dateAndTime,
          initialDateTime:
              v.dueDate ??
              DateTime.now()
                  .add(const Duration(days: 3))
                  .withTime(const LocalTime(hour: 9, minute: 0)),
          onChanged: (d) => _emit(v.copyWith(dueDate: d)),
        ),

        // Reminder
        HMBDateTimeField(
          label: 'Reminder',
          mode: HMBDateTimeFieldMode.dateAndTime,
          initialDateTime:
              v.remindAt ??
              DateTime.now()
                  .add(const Duration(days: 2))
                  .withTime(const LocalTime(hour: 9, minute: 0)),
          onChanged: (d) => _emit(v.copyWith(remindAt: d)),
        ).help(
          'Reminders',
          'Reminders may arrive a few minutes late to save battery',
        ),

        // Status (+ completedDate rule)
        HMBSelectChips<ToDoStatus>(
          label: 'Status',
          value: v.status,
          items: ToDoStatus.values,
          format: (x) => x.name,
          onChanged: (s) {
            final newStatus = s;
            final completedDate = newStatus == ToDoStatus.done
                ? DateTime.now()
                : null;
            _emit(v.copyWith(status: newStatus, completedDate: completedDate));
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }
}
