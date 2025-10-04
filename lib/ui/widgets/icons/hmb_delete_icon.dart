import 'package:flutter/material.dart';

import '../../../util/dart/types.dart';
import 'hmb_icon_button.dart';

class HMBDeleteIcon extends StatelessWidget {
  final AsyncVoidCallback onPressed;
  final String hint;
  final bool enabled;

  const HMBDeleteIcon({
    required this.onPressed,
    super.key,
    this.hint = 'Delete',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => HMBIconButton(
    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
    showBackground: false,
    hint: hint,
    enabled: enabled,
    onPressed: onPressed,
  );
}
