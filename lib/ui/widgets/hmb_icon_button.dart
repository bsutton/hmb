import 'package:flutter/material.dart';

enum HMBIconButtonSize { small, standard, large }

/// Displays an icon button with configurable size and tooltip.
class HMBIconButton extends StatelessWidget {
  const HMBIconButton({
    required this.onPressed,
    required this.hint,
    required this.icon,
    this.enabled = true,
    this.size = HMBIconButtonSize.standard,
    super.key,
  });

  final Future<void> Function()? onPressed;
  final bool enabled;
  final Icon icon;
  final String? hint;
  final HMBIconButtonSize size;

  // Define the size for each button size variant
  double get _size {
    switch (size) {
      case HMBIconButtonSize.small:
        return 32;
      case HMBIconButtonSize.large:
        return 64;
      case HMBIconButtonSize.standard:
        return 48;
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
        message: hint,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: Colors.lightBlue,
            radius: _size / 2, // CircleAvatar uses radius, so divide by 2
            child: IconButton(
              icon: icon,
              onPressed: enabled ? onPressed : null,
              iconSize: _size * 0.5, // Adjust the icon size proportionally
            ),
          ),
        ),
      );
}
