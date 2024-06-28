import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

typedef OnChanged = void Function(DateTime newValue);

/// Displays a Date Time picker.
/// The value is passed to the [onChanged] callback.
class HMBDateTimeField extends StatelessWidget {
  HMBDateTimeField(
      {required this.initialDateTime, required this.onChanged, super.key});

  final DateTime initialDateTime;
  final OnChanged onChanged;

  final format = DateFormat('EEE, d MMM H:mm');
  @override
  Widget build(BuildContext context) => Column(children: <Widget>[
        DateTimeField(
          format: format,
          initialValue: initialDateTime,
          onShowPicker: (context, currentValue) async => showDatePicker(
            context: context,
            firstDate: DateTime(1900),
            initialDate: currentValue ?? DateTime.now(),
            lastDate: DateTime(2100),
          ).then((date) async {
            if (date != null) {
              final time = await showTimePicker(
                context: context,
                initialTime:
                    TimeOfDay.fromDateTime(currentValue ?? DateTime.now()),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(alwaysUse24HourFormat: false),
                  child: child!,
                ),
              );
              final dt = DateTimeField.combine(date, time);
              onChanged(dt);
              return dt;
            } else {
              onChanged(currentValue!);
              return currentValue;
            }
          }),
        ),
      ]);
}
