import 'package:flutter/material.dart';

/// Capitalises the first letter of each word in the text field.
class HMBNameField extends StatelessWidget {
  const HMBNameField({
    required this.controller,
    required this.labelText,
    this.keyboardType = TextInputType.text,
    this.required = false,
    this.validator,
    this.focusNode,
    this.onChanged,
    super.key,
    this.autofocus = false,
    this.leadingSpace = true,
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

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (leadingSpace) const SizedBox(height: 16),
      TextFormField(
        onChanged: onChanged?.call,
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'Please enter a $labelText';
          }
          return validator?.call(value);
        },
      ),
    ],
  );
}
