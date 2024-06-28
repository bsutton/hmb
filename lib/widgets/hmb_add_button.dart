import 'package:flutter/material.dart';

/// Displays the primary site of a parent
/// and allows the user to select/update the primary site.
class HMBButtonAdd extends StatelessWidget {
  const HMBButtonAdd(
      {required this.onPressed, required this.enabled, super.key});
  final Future<void> Function() onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Add',
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
