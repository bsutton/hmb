import 'package:flutter/material.dart';

import '../../../util/dart/types.dart';
import 'hmb_icon_button.dart';

class HMBFilterIcon extends StatelessWidget {
  final AsyncVoidCallback onPressed;
  final String hint;
  final bool enabled;
  final bool small;
  final bool active;

  const HMBFilterIcon({
    required this.onPressed,
    this.small = false,
    this.active = false,
    super.key,
    this.hint = '''Filter and sort the list''',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => HMBIconButton(
    icon: Icon(Icons.tune, size: 20, color: active ? Colors.blue : null),
    size: small ? HMBIconButtonSize.small : HMBIconButtonSize.standard,
    showBackground: false,
    hint: hint,
    enabled: enabled,
    onPressed: onPressed,
  );
}
