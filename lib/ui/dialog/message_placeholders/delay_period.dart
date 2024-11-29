import 'package:flutter/material.dart';

import '../message_template_dialog.dart';
import 'place_holder.dart';

class DelayPeriod extends PlaceHolder<String> {
  DelayPeriod() : super(name: keyName, key: keyScope);

  static String keyName = 'delay_period';
  static String keyScope = 'delay_period';

  String? delayPeriod;

  // @override
  // PlaceHolderField<String> field(MessageData data)
  //=> _buildPeriodPicker(this);

  @override
  void setValue(String? value) {
    delayPeriod = value;
  }

  @override
  Future<String> value(MessageData data) async => delayPeriod ?? '';
}

/// Delay Period placeholder drop list
PlaceHolderField<String> _buildPeriodPicker(DelayPeriod placeholder) {
  final periods = <String>[
    '10 minutes',
    '15 minutes',
    '20 minutes',
    '30 minutes',
    '45 minutes',
    '1 hour',
    '1.5 hours',
    '2 hours'
  ];
  final widget = DropdownButtonFormField<String>(
    decoration: const InputDecoration(labelText: 'Delay Period'),
    value: placeholder.delayPeriod,
    items: periods
        .map((period) => DropdownMenuItem<String>(
              value: period,
              child: Text(period),
            ))
        .toList(),
    onChanged: (newValue) {
      placeholder.setValue(newValue ?? '');
      placeholder.onChanged?.call(newValue ?? '', ResetFields());
    },
  );
  return PlaceHolderField(
    placeholder: placeholder,
    widget: widget,
    getValue: (data) async => placeholder.value(data),
  );
}
