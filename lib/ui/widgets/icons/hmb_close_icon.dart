import 'package:flutter/material.dart';

import '../../../util/dart/types.dart';
import 'hmb_icon_button.dart';

class HMBCloseIcon extends StatelessWidget {
  final AsyncVoidCallback onPressed;
  final String hint;
  final bool enabled;
  final bool small;

  const HMBCloseIcon({
    required this.onPressed,
    this.small = true,
    super.key,
    this.hint = '''Close''',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => HMBIconButton(
    icon: const Icon(Icons.close, size: 20, color: Colors.white),
    size: small ? HMBIconButtonSize.small : HMBIconButtonSize.standard,
    showBackground: false,
    hint: hint,
    enabled: enabled,
    onPressed: onPressed,
  );
}
