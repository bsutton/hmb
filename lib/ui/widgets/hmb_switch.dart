import 'package:flutter/material.dart';

class HMBSwitch extends StatelessWidget {
  const HMBSwitch({
    required this.labelText,
    required this.initialValue,
    required this.onChanged,
    this.autofocus = false,
    this.focusNode,
    super.key,
    this.leadingSpace = true,
  });

  final bool? initialValue;
  final FocusNode? focusNode;
  final String labelText;
  final bool autofocus;
  final bool leadingSpace;

  // ignore: avoid_positional_boolean_parameters
  final void Function(bool newValue) onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (leadingSpace) const SizedBox(height: 16),
      SwitchListTile(
        focusNode: focusNode,
        title: Text(labelText),
        value: initialValue ?? false,
        onChanged: onChanged,
      ),
    ],
  );
}
