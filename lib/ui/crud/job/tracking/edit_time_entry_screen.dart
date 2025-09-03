import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

import 'package:sqflite_common/sqlite_api.dart';

import '../../../../dao/dao.g.dart';
import '../../../../entity/entity.g.dart';
import '../../../dialog/long_duration_dialog.dart';
import '../../../widgets/fields/fields.g.dart';
import '../../../widgets/hmb_toast.dart';
import '../../../widgets/select/select.g.dart';
import '../../base_nested/edit_nested_screen.dart';

class TimeEntryEditScreen extends StatefulWidget {
  final Job job;
  final TimeEntry? timeEntry;

  const TimeEntryEditScreen({required this.job, this.timeEntry, super.key});

  @override
  _TimeEntryEditScreenState createState() => _TimeEntryEditScreenState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TimeEntry?>('timeEntry', timeEntry));
  }
}

class _TimeEntryEditScreenState extends DeferredState<TimeEntryEditScreen>
    implements NestedEntityState<TimeEntry> {
  late TextEditingController _startDateController;
  late TextEditingController _startTimeController;
  late TextEditingController _endDateController;
  late TextEditingController _endTimeController;
  late TextEditingController _noteController;

  late FocusNode _startDateFocusNode;
  late FocusNode _startTimeFocusNode;
  late FocusNode _endDateFocusNode;
  late FocusNode _endTimeFocusNode;
  late FocusNode _noteFocusNode;

  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _timeFormat = DateFormat('hh:mm a');

  @override
  TimeEntry? currentEntity;
  Task? _selectedTask;

  final _selectedSupplier = SelectedSupplier();

  @override
  Future<void> asyncInitState() async {
    if (widget.timeEntry != null) {
      _selectedTask = await DaoTask().getById(widget.timeEntry!.taskId);
      _selectedSupplier.selected = (await DaoSupplier().getById(
        widget.timeEntry!.supplierId,
      ))?.id;
    }
  }

  @override
  void initState() {
    super.initState();
    currentEntity ??= widget.timeEntry;

    final now = DateTime.now();
    // Start date/time
    if (currentEntity != null) {
      final st = currentEntity!.startTime;
      _startDateController = TextEditingController(
        text: _dateFormat.format(st),
      );
      _startTimeController = TextEditingController(
        text: _timeFormat.format(st),
      );
    } else {
      _startDateController = TextEditingController(
        text: _dateFormat.format(now),
      );
      _startTimeController = TextEditingController(
        text: _timeFormat.format(now),
      );
    }
    // End date/time
    if (currentEntity?.endTime != null) {
      final et = currentEntity!.endTime!;
      _endDateController = TextEditingController(text: _dateFormat.format(et));
      _endTimeController = TextEditingController(text: _timeFormat.format(et));
    } else {
      _endDateController = TextEditingController(text: _dateFormat.format(now));
      _endTimeController = TextEditingController(
        text: _timeFormat.format(now.add(const Duration(minutes: 15))),
      );
    }
    _noteController = TextEditingController(text: currentEntity?.note ?? '');

    _startDateFocusNode = FocusNode();
    _startTimeFocusNode = FocusNode();
    _endDateFocusNode = FocusNode();
    _endTimeFocusNode = FocusNode();
    _noteFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_startDateFocusNode);
    });
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _startTimeController.dispose();
    _endDateController.dispose();
    _endTimeController.dispose();
    _noteController.dispose();
    _startDateFocusNode.dispose();
    _startTimeFocusNode.dispose();
    _endDateFocusNode.dispose();
    _endTimeFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) =>
      showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );

  Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay? initial) =>
      showTimePicker(
        context: context,
        initialTime: initial ?? TimeOfDay.now(),
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      );

  DateTime? _combine(String dateText, String timeText) {
    if (dateText.isEmpty || timeText.isEmpty) {
      return null;
    }
    final d = _dateFormat.tryParse(dateText);
    final tdt = _timeFormat.tryParse(timeText);
    if (d == null || tdt == null) {
      return null;
    }
    return DateTime(d.year, d.month, d.day, tdt.hour, tdt.minute);
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => NestedEntityEditScreen<TimeEntry, Job>(
      entityName: 'Time Entry',
      dao: DaoTimeEntry(),
      onInsert: (e, tx) => DaoTimeEntry().insert(e!, tx),
      entityState: this,
      crossValidator: () async {
        final start =
            _combine(_startDateController.text, _startTimeController.text) ??
            DateTime.now();
        final end = _combine(_endDateController.text, _endTimeController.text);
        if (end != null) {
          if (end.isBefore(start)) {
            HMBToast.error('End must be after the Start');
            return false;
          }
          final duration = end.difference(start);
          if (duration.inHours > TimeEntry.longDurationHours) {
            final confirm = await showLongDurationDialog(context, duration);
            if (!confirm) {
              return false;
            }
          }
        }
        return true;
      },
      editor: (timeEntry) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HMBDroplist<Task>(
            title: 'Select Task',
            selectedItem: () async => _selectedTask,
            items: (filter) => DaoTask().getTasksByJob(widget.job.id),
            format: (task) => task.name,
            onChanged: (task) => setState(() => _selectedTask = task),
          ),

          HMBSelectSupplier(selectedSupplier: _selectedSupplier),
          // Start date
          GestureDetector(
            onTap: () async {
              final picked = await _pickDate(
                context,
                _dateFormat.tryParse(_startDateController.text),
              );
              if (picked != null) {
                _startDateController.text = _dateFormat.format(picked);
              }
            },
            child: AbsorbPointer(
              child: HMBTextField(
                controller: _startDateController,
                focusNode: _startDateFocusNode,
                labelText: 'Start Date',
                keyboardType: TextInputType.datetime,
                validator: (v) => _dateFormat.tryParse(v ?? '') == null
                    ? 'Enter valid date'
                    : null,
              ),
            ),
          ),

          // Start time
          GestureDetector(
            onTap: () async {
              final initial = _timeFormat.tryParse(_startTimeController.text);
              final picked = await _pickTime(
                context,
                initial != null
                    ? TimeOfDay(hour: initial.hour, minute: initial.minute)
                    : null,
              );
              if (picked != null) {
                final dt = DateTime(0, 0, 0, picked.hour, picked.minute);
                _startTimeController.text = _timeFormat.format(dt);
              }
            },
            child: AbsorbPointer(
              child: HMBTextField(
                controller: _startTimeController,
                focusNode: _startTimeFocusNode,
                labelText: 'Start Time',
                keyboardType: TextInputType.datetime,
                validator: (v) => _timeFormat.tryParse(v ?? '') == null
                    ? 'Enter valid time'
                    : null,
              ),
            ),
          ),

          // End date
          GestureDetector(
            onTap: () async {
              final picked = await _pickDate(
                context,
                _dateFormat.tryParse(_endDateController.text),
              );
              if (picked != null) {
                _endDateController.text = _dateFormat.format(picked);
              }
            },
            child: AbsorbPointer(
              child: HMBTextField(
                controller: _endDateController,
                focusNode: _endDateFocusNode,
                labelText: 'End Date',
                keyboardType: TextInputType.datetime,
                validator: (v) =>
                    v != null && v.isNotEmpty && _dateFormat.tryParse(v) == null
                    ? 'Enter valid date'
                    : null,
              ),
            ),
          ),

          // End time
          GestureDetector(
            onTap: () async {
              final initial = _timeFormat.tryParse(_endTimeController.text);
              final picked = await _pickTime(
                context,
                initial != null
                    ? TimeOfDay(hour: initial.hour, minute: initial.minute)
                    : null,
              );
              if (picked != null) {
                final dt = DateTime(0, 0, 0, picked.hour, picked.minute);
                _endTimeController.text = _timeFormat.format(dt);
              }
            },
            child: AbsorbPointer(
              child: HMBTextField(
                controller: _endTimeController,
                focusNode: _endTimeFocusNode,
                labelText: 'End Time',
                keyboardType: TextInputType.datetime,
                validator: (v) =>
                    v != null && v.isNotEmpty && _timeFormat.tryParse(v) == null
                    ? 'Enter valid time'
                    : null,
              ),
            ),
          ),

          HMBTextField(
            controller: _noteController,
            focusNode: _noteFocusNode,
            labelText: 'Note',
          ),
        ],
      ),
    ),
  );

  @override
  Future<TimeEntry> forUpdate(TimeEntry timeEntry) async => timeEntry.copyWith(
    taskId: _selectedTask!.id,
    supplierId: _selectedSupplier.selected,
    startTime: _combine(_startDateController.text, _startTimeController.text),
    endTime: _combine(_endDateController.text, _endTimeController.text),
    note: _noteController.text,
  );

  @override
  Future<TimeEntry> forInsert() async => TimeEntry.forInsert(
    taskId: _selectedTask!.id,
    supplierId: _selectedSupplier.selected,
    startTime: _combine(_startDateController.text, _startTimeController.text)!,
    endTime: _combine(_endDateController.text, _endTimeController.text),
    note: _noteController.text,
  );

  @override
  void refresh() => setState(() {});

  @override
  Future<void> postSave(Transaction transaction, Operation operation) async {}
}
