import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Tooltip(
        message: hint,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: Colors.lightBlue,
            child: IconButton(
                icon: const Icon(Icons.add),
                onPressed: enabled ? onPressed : null),
          ),
        ),
      );
}
