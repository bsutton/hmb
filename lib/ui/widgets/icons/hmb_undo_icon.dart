import 'package:flutter/material.dart';
import '../../../util/dart/types.dart';
import 'hmb_icon_button.dart';

class HMBUndoIcon extends StatelessWidget {
  final AsyncVoidCallback onPressed;
  final String hint;
  final bool enabled;
  final bool small;

  const HMBUndoIcon({
    required this.onPressed,
    this.small = true,
    super.key,
    this.hint = '''Undo the last action''',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => HMBIconButton(
    icon: const Icon(Icons.undo, size: 20, color: Colors.orange),
    size: small ? HMBIconButtonSize.small : HMBIconButtonSize.standard,
    showBackground: false,
    hint: hint,
    enabled: enabled,
    onPressed: onPressed,
  );
}
