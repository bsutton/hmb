import 'package:flutter/material.dart';

import '../../util/flutter/flutter_util.g.dart';
import 'color_ex.dart';

enum HMBChipTone { neutral, accent, danger, warning }

class HMBChip extends StatelessWidget {
  final String label;
  final HMBChipTone tone;
  final IconData? icon;
  final VoidCallback? onTap;

  const HMBChip({
    required this.label,
    super.key,
    this.tone = HMBChipTone.neutral,
    this.icon,
    this.onTap,
  });

  Color _backgroundColor(BuildContext context) {
    switch (tone) {
      case HMBChipTone.accent:
        return Theme.of(context).colorScheme.primary.withSafeOpacity(0.15);
      case HMBChipTone.danger:
        return Colors.red.withSafeOpacity(0.15);
      case HMBChipTone.warning:
        return Colors.orange.withSafeOpacity(0.15);
      case HMBChipTone.neutral:
        // Slightly stronger tint for better white text contrast
        return Theme.of(context).colorScheme.primary.withSafeOpacity(0.25);
    }
  }

  Color _textColor(BuildContext context) {
    switch (tone) {
      case HMBChipTone.accent:
        return Theme.of(context).colorScheme.primary;
      case HMBChipTone.danger:
        return Colors.red.shade400;
      case HMBChipTone.warning:
        return Colors.orange.shade700;
      case HMBChipTone.neutral:
        // White text for stronger contrast
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _backgroundColor(context);
    final textColor = _textColor(context);

    final chipContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: chipContent,
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: chip,
      );
    }
    return chip;
  }
}

/// Chip tone helper based on due date.
/// - Overdue  -> danger
/// - Today    -> accent
/// - Future   -> neutral
HMBChipTone dueTone(DateTime? due, {DateTime? now}) {
  if (due == null) {
    return HMBChipTone.neutral;
  }
  final n = (now ?? DateTime.now()).toLocal();
  final d = due.toLocal();

  if (d.isBefore(n)) {
    return HMBChipTone.danger;
  }
  if (d.sameDay(n)) {
    return HMBChipTone.accent;
  }
  return HMBChipTone.neutral;
}
