import 'package:flutter/material.dart';

import '../../../util/dart/types.dart';
import 'hmb_icon_button.dart';

class HMBFilterIcon extends StatelessWidget {
  final AsyncVoidCallback onPressed;
  final String hint;
  final bool enabled;
  final bool small;

  const HMBFilterIcon({
    required this.onPressed,
    this.small = false,
    super.key,
    this.hint = '''Filter and sort the list''',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => HMBIconButton(
    icon: const Icon(Icons.tune, size: 20),
    size: small ? HMBIconButtonSize.small : HMBIconButtonSize.standard,
    showBackground: false,
    hint: hint,
    enabled: enabled,
    onPressed: onPressed,
  );
}
