import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../util/money_ex.dart';
import 'hmb_text_field.dart';

class HMBMoneyField extends HMBTextField {
  factory HMBMoneyField(
          {required TextEditingController controller,
          required String labelText,
          required String fieldName,
          bool nonZero = true,
          TextInputType keyboardType = TextInputType.text,
          bool required = false,
          FocusNode? focusNode,
          ValueChanged<String?>? onChanged,
          Key? key,
          bool autofocus = false,
          bool leadingSpace = true}) =>
      HMBMoneyField._(
          controller: controller,
          labelText: labelText,
          fieldName: fieldName,
          nonZero: nonZero,
          keyboardType: keyboardType,
          required: required,
          focusNode: focusNode,
          onChanged: onChanged,
          key: key,
          autofocus: autofocus,
          leadingSpace: leadingSpace,
          validator: (value) => validation(value, nonZero, fieldName));

  const HMBMoneyField._(
      {required super.controller,
      required super.labelText,
      required this.fieldName,
      this.nonZero = true,
      super.keyboardType = TextInputType.text,
      super.required = false,
      super.focusNode,
      super.onChanged,
      super.key,
      super.autofocus = false,
      super.leadingSpace = true,
      super.validator});

  final String fieldName;
  final bool nonZero;

  // ignore: avoid_positional_boolean_parameters
  static String? validation(String? value, bool nonZero, String fieldName) {
    if (nonZero) {
      if (value == null || value.isEmpty) {
        return 'Please enter a $fieldName';
      } else {
        if (Money.parse(value, isoCode: 'AUD') == MoneyEx.zero) {
          return 'Please enter a $fieldName greater than zero';
        }
      }
    }
    // no error
    return null;
  }
}
