import 'package:flutter/material.dart';
import '../../../util/dart/types.dart';
import 'hmb_icon_button.dart';

class HMBClearIcon extends StatelessWidget {
  final AsyncVoidCallback onPressed;
  final String hint;
  final bool enabled;
  final bool small;

  const HMBClearIcon({
    required this.onPressed,
    this.small = true,
    super.key,
    this.hint = '''Clear the field's contents''',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => HMBIconButton(
    icon: const Icon(Icons.clear, size: 20),
    size: small ? HMBIconButtonSize.small : HMBIconButtonSize.standard,
    showBackground: false,
    hint: hint,
    enabled: enabled,
    onPressed: onPressed,
  );
}
