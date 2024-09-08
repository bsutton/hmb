import 'package:flutter/material.dart' as m;
import 'package:intl/intl.dart';

import 'hmb_spacer.dart';
import 'hmb_text.dart';

typedef OnChanged = void Function(DateTime newValue);

/// Displays a Date and Time picker in separate fields.
/// The value is passed to the [onChanged] callback.
class HMBDateTimeField extends m.StatefulWidget {
  const HMBDateTimeField({
    required this.label,
    required this.initialDateTime,
    required this.onChanged,
    super.key,
  });

  final String label;
  final DateTime initialDateTime;
  final OnChanged onChanged;

  @override
  // ignore: library_private_types_in_public_api
  _HMBDateTimeFieldState createState() => _HMBDateTimeFieldState();
}

class _HMBDateTimeFieldState extends m.State<HMBDateTimeField> {
  late DateTime selectedDateTime;
  late m.TextEditingController dateController;
  late m.TextEditingController timeController;

  final dateFormat = DateFormat('EEE, d MMM yyyy');
  final timeFormat = DateFormat('h:mm a');

  @override
  void initState() {
    super.initState();
    selectedDateTime = widget.initialDateTime;
    dateController =
        m.TextEditingController(text: dateFormat.format(selectedDateTime));
    timeController =
        m.TextEditingController(text: timeFormat.format(selectedDateTime));
  }

  @override
  void dispose() {
    dateController.dispose();
    timeController.dispose();
    super.dispose();
  }

  @override
  m.Widget build(m.BuildContext context) => m.Row(
        crossAxisAlignment: m.CrossAxisAlignment.end,
        children: <m.Widget>[
          HMBText(
            widget.label,
            bold: true,
          ),
          const HMBSpacer(width: true),
          m.SizedBox(
            width: 140,
            child: m.TextFormField(
              readOnly: true,
              decoration: const m.InputDecoration(
                labelText: 'Select Date',
              ),
              controller: dateController,
              onTap: () async {
                final date = await _showDatePicker(context, selectedDateTime);
                if (date != null) {
                  setState(() {
                    selectedDateTime = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      selectedDateTime.hour,
                      selectedDateTime.minute,
                    );
                    dateController.text = dateFormat.format(selectedDateTime);
                  });
                  widget.onChanged(selectedDateTime);
                }
              },
            ),
          ),
          const HMBSpacer(width: true),
          m.SizedBox(
            width: 80,
            child: m.TextFormField(
              readOnly: true,
              decoration: const m.InputDecoration(
                labelText: 'Select Time',
              ),
              controller: timeController,
              onTap: () async {
                final time = await _showTimePicker(context, selectedDateTime);
                if (time != null) {
                  setState(() {
                    selectedDateTime = DateTime(
                      selectedDateTime.year,
                      selectedDateTime.month,
                      selectedDateTime.day,
                      time.hour,
                      time.minute,
                    );
                    timeController.text = timeFormat.format(selectedDateTime);
                  });
                  widget.onChanged(selectedDateTime);
                }
              },
            ),
          ),
        ],
      );

  Future<m.TimeOfDay?> _showTimePicker(
          m.BuildContext context, DateTime? currentValue) async =>
      m.showTimePicker(
        context: context,
        initialTime: m.TimeOfDay.fromDateTime(currentValue ?? DateTime.now()),
        builder: (context, child) => m.MediaQuery(
          data: m.MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      );

  Future<DateTime?> _showDatePicker(
          m.BuildContext context, DateTime? currentValue) =>
      m.showDatePicker(
        context: context,
        firstDate: DateTime(1900),
        initialDate: currentValue ?? DateTime.now(),
        lastDate: DateTime(2100),
      );
}
