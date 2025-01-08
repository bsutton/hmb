import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'layout/hmb_spacer.dart';
import 'text/hmb_text.dart';

typedef OnChanged = void Function(DateTime newValue);
typedef Validator = String? Function(DateTime?);

enum HMBDateTimeFieldMode { dateOnly, timeOnly, dateAndTime }

/// Displays a Date and Time picker in separate fields.
/// The value is passed to the [onChanged] callback.
class HMBDateTimeField extends StatefulWidget {
  const HMBDateTimeField({
    required this.label,
    required this.initialDateTime,
    required this.onChanged,
    required this.mode,
    this.validator,
    this.width = 180,
    super.key,
    this.labelWidth = double.infinity,
  });

  final String label;
  final DateTime initialDateTime;
  final OnChanged onChanged;
  final Validator? validator;
  final double width;
  final double labelWidth;
  final HMBDateTimeFieldMode mode;

  @override
  // ignore: library_private_types_in_public_api
  _HMBDateTimeFieldState createState() => _HMBDateTimeFieldState();
}

class _HMBDateTimeFieldState extends State<HMBDateTimeField> {
  late DateTime selectedDateTime;
  late TextEditingController dateController;
  late TextEditingController timeController;

  final dateFormat = DateFormat('EEE, d MMM yyyy');
  final timeFormat = DateFormat('h:mm a');

  @override
  void initState() {
    super.initState();
    selectedDateTime = widget.initialDateTime;
    dateController =
        TextEditingController(text: dateFormat.format(selectedDateTime));
    timeController =
        TextEditingController(text: timeFormat.format(selectedDateTime));
  }

  @override
  void didUpdateWidget(covariant HMBDateTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDateTime != oldWidget.initialDateTime) {
      selectedDateTime = widget.initialDateTime;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateControllers();
      });
    }
  }

  void _updateControllers() {
    dateController.text = dateFormat.format(selectedDateTime);
    timeController.text = timeFormat.format(selectedDateTime);
  }

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          SizedBox(
            width: widget.labelWidth,
            child: HMBText(
              widget.label,
              bold: true,
            ),
          ),
          if (widget.mode != HMBDateTimeFieldMode.timeOnly)
            SizedBox(
              width: widget.width,
              child: FormField<DateTime>(
                initialValue: selectedDateTime,
                validator: (value) => widget.validator?.call(value),
                builder: (field) => InkWell(
                  onTap: () async {
                    final date =
                        await _showDatePicker(context, selectedDateTime);
                    if (date != null) {
                      setState(() {
                        selectedDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          selectedDateTime.hour,
                          selectedDateTime.minute,
                        );
                        dateController.text =
                            dateFormat.format(selectedDateTime);
                      });
                      widget.onChanged(selectedDateTime);
                      field.didChange(selectedDateTime);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Select Date',
                      errorText: field.errorText,
                    ),
                    child: Text(dateController.text),
                  ),
                ),
              ),
            ),
          if (widget.mode == HMBDateTimeFieldMode.dateAndTime)
            const HMBSpacer(width: true),
          if (widget.mode != HMBDateTimeFieldMode.dateOnly)
            SizedBox(
              width: widget.width,
              child: FormField<DateTime>(
                initialValue: selectedDateTime,
                validator: (value) => widget.validator?.call(value),
                builder: (field) => InkWell(
                  onTap: () async {
                    final time =
                        await _showTimePicker(context, selectedDateTime);
                    if (time != null) {
                      setState(() {
                        selectedDateTime = DateTime(
                          selectedDateTime.year,
                          selectedDateTime.month,
                          selectedDateTime.day,
                          time.hour,
                          time.minute,
                        );
                        timeController.text =
                            timeFormat.format(selectedDateTime);
                      });
                      widget.onChanged(selectedDateTime);
                      field.didChange(selectedDateTime);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Select Time',
                      errorText: field.errorText,
                    ),
                    child: Text(timeController.text),
                  ),
                ),
              ),
            ),
        ],
      );

  Future<TimeOfDay?> _showTimePicker(
          BuildContext context, DateTime? currentValue) async =>
      showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(currentValue ?? DateTime.now()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      );

  Future<DateTime?> _showDatePicker(
          BuildContext context, DateTime? currentValue) =>
      showDatePicker(
        context: context,
        firstDate: DateTime(1900),
        initialDate: currentValue ?? DateTime.now(),
        lastDate: DateTime(2100),
      );
}
