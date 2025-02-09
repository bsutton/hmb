import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../util/platform_ex.dart';
import '../hmb_mail_to_icon.dart';

class HMBEmailField extends StatelessWidget {
  const HMBEmailField(
      {required this.labelText,
      required this.controller,
      this.required = false,
      super.key,
      this.validator,
      this.autofocus = false});

  final TextEditingController controller;
  final String? Function(String? value)? validator;

  final String labelText;
  final bool required;

  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        autofocus: isNotMobile,
        decoration: InputDecoration(
          labelText: labelText,
          suffixIcon: HMBMailToIcon(controller.text),
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'Please enter the email address';
          }

          if (Strings.isNotBlank(value)) {
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
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
