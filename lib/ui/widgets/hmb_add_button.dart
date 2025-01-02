import 'package:flutter/material.dart';

import 'hmb_icon_button.dart';

/// Displays the primary site of a parent
/// and allows the user to select/update the primary site.
class HMBButtonAdd extends StatelessWidget {
  const HMBButtonAdd({
    required this.onPressed,
    required this.enabled,
    this.hint = 'Add',
    super.key,
  });
  final Future<void> Function()? onPressed;
  final bool enabled;

  final String? hint;

  @override
  Widget build(BuildContext context) => HMBIconButton(
      onPressed: onPressed,
      enabled: enabled,
      hint: hint,
      icon: const Icon(Icons.add));
}
