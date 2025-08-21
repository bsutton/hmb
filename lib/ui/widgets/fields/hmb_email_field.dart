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
import 'package:flutter/services.dart';
import 'package:strings/strings.dart';

import '../../../util/parse/parse.dart';
import '../../../util/platform_ex.dart';
import '../hmb_mail_to_icon.dart';
import 'fields.g.dart';

class HMBEmailField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String? value)? validator;

  final String labelText;
  final bool required;

  final bool autofocus;

  const HMBEmailField({
    required this.labelText,
    required this.controller,
    this.required = false,
    super.key,
    this.validator,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) => HMBTextField(
    controller: controller,
    autofocus: isNotMobile,
    inputFormatters: [LowerCaseTextFormatter()], // force lowercase
    labelText: labelText,
    suffixIcon: HMBMailToIcon(controller.text),
    onPaste: parseEmail,
    validator: (value) {
      if (required && (value == null || value.isEmpty)) {
        return 'Please enter the email address';
      }

      if (Strings.isNotBlank(value)) {
        if (!isValidEmail(value!)) {
          return 'Please enter a valid email address';
        }
      }

      if (validator != null) {
        return validator!(value);
      }
      return null;
    },
  );
}

/// A TextInputFormatter that lower-cases all input.
class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lower = newValue.text.toLowerCase();
    return newValue.copyWith(
      text: lower,
      // preserve the cursor position at the end of the new text
      selection: TextSelection.collapsed(offset: lower.length),
    );
  }
}
