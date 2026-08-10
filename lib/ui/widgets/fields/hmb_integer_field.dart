/*
 Copyright © OnePub IP Pty Ltd.
 S. Brett Sutton. All Rights Reserved.
*/

import 'package:flutter/services.dart';

import 'hmb_text_field.dart';

/// Standard HMB field for whole-number values.
class HMBIntegerField extends HMBTextField {
  HMBIntegerField({
    required super.controller,
    required super.labelText,
    super.required,
    bool positive = false,
    super.onChanged,
    super.key,
  }) : super(
         keyboardType: TextInputType.number,
         inputFormatters: [FilteringTextInputFormatter.digitsOnly],
         validator: (value) {
           final parsed = int.tryParse(value ?? '');
           if (parsed == null) {
             return 'Enter a whole number';
           }
           if (positive && parsed <= 0) {
             return 'Enter a whole number greater than zero';
           }
           return null;
         },
       );
}
