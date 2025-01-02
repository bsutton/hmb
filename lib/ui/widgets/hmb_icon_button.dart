import 'package:flutter/material.dart';

/// Displays the primary site of a parent
/// and allows the user to select/update the primary site.
class HMBIconButton extends StatelessWidget {
  const HMBIconButton({
    required this.onPressed,
    required this.hint,
    required this.icon,
     this.enabled = true,
    super.key,
  });
  final Future<void> Function()? onPressed;
  final bool enabled;
  final Icon icon;
  final String? hint;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: hint,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: Colors.lightBlue,
            child:
                IconButton(icon: icon, onPressed: enabled ? onPressed : null),
          ),
        ),
      );
}
