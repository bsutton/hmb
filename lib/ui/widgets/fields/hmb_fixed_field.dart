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

import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../../../util/dart/money_ex.dart';
import 'hmb_text_field.dart';

class HMBFixedField extends HMBTextField {
  final String fieldName;
  final bool nonZero;

  factory HMBFixedField({
    required HMBFixedEditingController controller,
    required String labelText,
    required String fieldName,
    bool nonZero = true,
    bool required = false,
    FocusNode? focusNode,
    ValueChanged<String?>? onChanged,
    Key? key,
    bool autofocus = false,
  }) => HMBFixedField._(
    controller: controller,
    labelText: labelText,
    fieldName: fieldName,
    nonZero: nonZero,
    required: required,
    focusNode: focusNode,
    onChanged: onChanged,
    key: key,
    autofocus: autofocus,
    validator: (value) => validation(value, nonZero, fieldName),
  );

  const HMBFixedField._({
    required super.controller,
    required super.labelText,
    required this.fieldName,
    this.nonZero = true,
    super.required = false,
    super.focusNode,
    super.onChanged,
    super.key,
    super.autofocus = false,
    super.validator,
  }) : super(keyboardType: TextInputType.text);

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

class HMBFixedEditingController extends TextEditingController {
  final Fixed? fixed;

  HMBFixedEditingController({required this.fixed})
    : super(text: fixed == null || fixed.isZero ? '' : fixed.toString());
}
