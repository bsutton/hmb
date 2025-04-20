import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../util/hmb_theme.dart';

class HMBTextField extends StatelessWidget {
  /// A customizable text field that supports disabling/enabling input.
  const HMBTextField({
    required this.controller,
    required this.labelText,
    this.keyboardType = TextInputType.text,
    this.required = false,
    this.validator,
    this.focusNode,
    this.onChanged,
    this.enabled = true,
    super.key,
    this.autofocus = false,
    this.leadingSpace = true,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final String? Function(String? value)? validator;
  final bool autofocus;
  final bool required;
  final bool leadingSpace;
  final TextInputType keyboardType;
  final void Function(String?)? onChanged;
  final TextCapitalization textCapitalization;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (leadingSpace) const SizedBox(height: 16),
      TextFormField(
          style: const TextStyle(color: HMBColors.textPrimary),
        enabled: enabled,
        readOnly: !enabled,
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        onChanged: onChanged?.call,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (required && enabled && Strings.isBlank(value)) {
            return 'Please enter a $labelText';
          }
          return validator?.call(value);
        },
      ),
    ],
  );
}
