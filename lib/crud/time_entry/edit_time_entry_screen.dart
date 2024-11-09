import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_time_entry.dart';
import '../../entity/task.dart';
import '../../entity/time_entry.dart';
import '../../util/format.dart';
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

  @override
  TimeEntry? currentEntity;

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.timeEntry;
    _startTimeController = TextEditingController(
        text: currentEntity != null
            ? _dateTimeFormat.format(currentEntity!.startTime.toLocal())
            : '');
    _endTimeController = TextEditingController(
        text: currentEntity?.endTime != null
            ? _dateTimeFormat.format(currentEntity!.endTime!.toLocal())
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

  Future<void> _selectDateTime(
      BuildContext context, TextEditingController controller) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (selectedDate != null && context.mounted) {
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
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
        controller.text = _dateTimeFormat.format(finalDateTime);
      }
    }
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
              onTap: () async => _selectDateTime(context, _startTimeController),
              child: AbsorbPointer(
                child: HMBTextField(
                  controller: _startTimeController,
                  focusNode: _startTimeFocusNode,
                  labelText: 'Start Time',
                  keyboardType: TextInputType.datetime,
                  required: true,
                  validator: (value) => (parseDateTime(value) == null)
                      ? 'You must enter a valid Start Time'
                      : null,
                ),
              ),
            ),
            GestureDetector(
              onTap: () async => _selectDateTime(context, _endTimeController),
              child: AbsorbPointer(
                child: HMBTextField(
                  controller: _endTimeController,
                  focusNode: _endTimeFocusNode,
                  labelText: 'End Time',
                  keyboardType: TextInputType.datetime,
                  required: true,

                  /// end time must be after start time.
                  validator: (value) => (Strings.isNotBlank(value) &&
                          (!parseDateTime(value ?? '')!.isAfter(
                              parseDateTime(_startTimeController.text) ??
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
      startTime: _dateTimeFormat.parse(_startTimeController.text),
      endTime: _endTimeController.text.isNotEmpty
          ? _dateTimeFormat.parse(_endTimeController.text)
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
