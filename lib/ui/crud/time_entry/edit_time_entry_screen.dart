import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_time_entry.dart';
import '../../../entity/task.dart';
import '../../../entity/time_entry.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../base_nested/edit_nested_screen.dart';

class TimeEntryEditScreen extends StatefulWidget {
  const TimeEntryEditScreen({required this.task, super.key, this.timeEntry});
  final Task task;
  final TimeEntry? timeEntry;

  @override
  // ignore: library_private_types_in_public_api
  _TimeEntryEditScreenState createState() => _TimeEntryEditScreenState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TimeEntry?>('timeEntry', timeEntry));
  }
}

class _TimeEntryEditScreenState extends State<TimeEntryEditScreen>
    implements NestedEntityState<TimeEntry> {
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _noteController;
  late FocusNode _startTimeFocusNode;
  late FocusNode _endTimeFocusNode;
  late FocusNode _noteFocusNode;
  final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd hh:mm a');

  String _formatDateTime(DateTime dateTime) =>
      _dateTimeFormat.format(dateTime.toLocal());

  DateTime? _parseDateTime(String? dateTime) =>
      _dateTimeFormat.tryParse(dateTime ?? '');

  @override
  TimeEntry? currentEntity;

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.timeEntry;
    _startTimeController = TextEditingController(
        text: currentEntity != null
            ? _formatDateTime(currentEntity!.startTime)
            : '');
    _endTimeController = TextEditingController(
        text: currentEntity?.endTime != null
            ? _formatDateTime(currentEntity!.endTime!)
            : '');
    _noteController = TextEditingController(text: currentEntity?.note ?? '');

    _startTimeFocusNode = FocusNode();
    _endTimeFocusNode = FocusNode();
    _noteFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_startTimeFocusNode);
    });
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _noteController.dispose();
    _startTimeFocusNode.dispose();
    _endTimeFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  Future<DateTime?> _selectDateTime(
      BuildContext context, DateTime? initialDate) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (selectedDate != null && context.mounted) {
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate ?? DateTime.now()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      );

      if (selectedTime != null) {
        final finalDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );
        return finalDateTime;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => NestedEntityEditScreen<TimeEntry, Task>(
        entityName: 'Time Entry',
        dao: DaoTimeEntry(),
        onInsert: (timeEntry) async => DaoTimeEntry().insert(timeEntry!),
        entityState: this,
        editor: (timeEntry) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: () async {
                final selectedDateTime = await _selectDateTime(
                    context, _parseDateTime(_startTimeController.text));
                if (selectedDateTime != null) {
                  _startTimeController.text = _formatDateTime(selectedDateTime);
                }
              },
              child: AbsorbPointer(
                child: HMBTextField(
                  controller: _startTimeController,
                  focusNode: _startTimeFocusNode,
                  labelText: 'Start Time',
                  keyboardType: TextInputType.datetime,
                  required: true,
                  validator: (value) => (_parseDateTime(value) == null)
                      ? 'You must enter a valid Start Time'
                      : null,
                ),
              ),
            ),
            GestureDetector(
              onTap: () async {
                final selectedDateTime = await _selectDateTime(
                    context, _parseDateTime(_endTimeController.text));
                if (selectedDateTime != null) {
                  _endTimeController.text = _formatDateTime(selectedDateTime);
                }
              },
              child: AbsorbPointer(
                child: HMBTextField(
                  controller: _endTimeController,
                  focusNode: _endTimeFocusNode,
                  labelText: 'End Time',
                  keyboardType: TextInputType.datetime,
                  required: true,

                  /// end time must be after start time.
                  validator: (value) => (Strings.isNotBlank(value) &&
                          (!_parseDateTime(value)!.isAfter(
                              _parseDateTime(_startTimeController.text) ??
                                  DateTime.now())))
                      ? 'End time must be after start time'
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
      );

  @override
  Future<TimeEntry> forUpdate(TimeEntry timeEntry) async => TimeEntry.forUpdate(
      entity: timeEntry,
      taskId: widget.task.id,
      startTime: _parseDateTime(_startTimeController.text)!,
      endTime: _endTimeController.text.isNotEmpty
          ? _parseDateTime(_endTimeController.text)
          : null,
      note: _noteController.text);

  @override
  Future<TimeEntry> forInsert() async => TimeEntry.forInsert(
      taskId: widget.task.id,
      startTime: _dateTimeFormat.parse(_startTimeController.text),
      endTime: _dateTimeFormat.parse(_endTimeController.text),
      note: _noteController.text);

  @override
  void refresh() {
    setState(() {});
  }
}
