import 'package:flutter/material.dart';

import '../../util/dart/types.dart';
import 'hmb_icon_button.dart';

class HMBEditIcon extends StatelessWidget {
  final AsyncVoidCallback onPressed;
  final String hint;
  final bool enabled;

  const HMBEditIcon({
    required this.onPressed,
    required this.hint,
    super.key,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => HMBIconButton(
    icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
    showBackground: false,
    hint: hint,
    enabled: enabled,
    onPressed: onPressed,
  );
}
