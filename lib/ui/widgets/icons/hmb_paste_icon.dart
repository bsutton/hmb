import 'package:flutter/material.dart';

import '../../../util/dart/types.dart';
import 'hmb_icon_button.dart';

class HMBPasteIcon extends StatelessWidget {
  final AsyncVoidCallback onPressed;
  final String hint;
  final bool enabled;
  final bool small;

  const HMBPasteIcon({
    required this.onPressed,
    this.small = true,
    super.key,
    this.hint = '''Paste the clipboard contents''',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => HMBIconButton(
    icon: const Icon(Icons.paste, size: 20),
    size: small ? HMBIconButtonSize.small : HMBIconButtonSize.standard,
    showBackground: false,
    hint: hint,
    enabled: enabled,
    onPressed: onPressed,
  );
}
