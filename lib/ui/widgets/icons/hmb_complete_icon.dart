import 'package:flutter/material.dart';
import '../../../util/dart/types.dart';
import 'hmb_icon_button.dart';

class HMBCompleteIcon extends StatelessWidget {
  final AsyncVoidCallback onPressed;
  final String hint;
  final bool enabled;
  final bool small;

  const HMBCompleteIcon({
    required this.onPressed,
    this.small = false,
    super.key,
    this.hint = '''Mark the item as complete''',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => HMBIconButton(
    icon: const Icon(Icons.check, size: 20, color: Colors.green),
    size: small ? HMBIconButtonSize.small : HMBIconButtonSize.standard,
    showBackground: false,
    hint: hint,
    enabled: enabled,
    onPressed: onPressed,
  );
}
