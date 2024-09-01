import 'package:flutter/material.dart' as m;
import 'package:intl/intl.dart';

import 'hmb_spacer.dart';
import 'hmb_text.dart';

typedef OnChanged = void Function(DateTime newValue);

/// Displays a Date and Time picker in separate fields.
/// The value is passed to the [onChanged] callback.
class HMBDateTimeField extends m.StatelessWidget {
  HMBDateTimeField({
    required this.label,
    required this.initialDateTime,
    required this.onChanged,
    super.key,
  });

  final String label;

  final DateTime initialDateTime;
  final OnChanged onChanged;

  final dateFormat = DateFormat('EEE, d MMM yyyy');
  final timeFormat = DateFormat('H:mm');

  @override
  m.Widget build(m.BuildContext context) => m.Row(
        crossAxisAlignment: m.CrossAxisAlignment.end,
        children: <m.Widget>[
          HMBText(
            label,
            bold: true,
          ),
          const HMBSpacer(width: true),
          m.SizedBox(
              width: 120,
              child: m.TextFormField(
                readOnly: true,
                decoration: const m.InputDecoration(
                  labelText: 'Select Date',
                ),
                initialValue: dateFormat.format(initialDateTime),
                onTap: () async {
                  final date = await _showDatePicker(context, initialDateTime);
                  if (date != null) {
                    final newDateTime = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      initialDateTime.hour,
                      initialDateTime.minute,
                    );
                    onChanged(newDateTime);
                  }
                },
              )),
          const HMBSpacer(width: true),
          m.SizedBox(
              width: 80,
              child: m.TextFormField(
                readOnly: true,
                decoration: const m.InputDecoration(
                  labelText: 'Select Time',
                ),
                initialValue: timeFormat.format(initialDateTime),
                onTap: () async {
                  final time = await _showTimePicker(context, initialDateTime);
                  if (time != null) {
                    final newDateTime = DateTime(
                      initialDateTime.year,
                      initialDateTime.month,
                      initialDateTime.day,
                      time.hour,
                      time.minute,
                    );
                    onChanged(newDateTime);
                  }
                },
              )),
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
