/*
 Copyright © OnePub IP Pty Ltd.
 All Rights Reserved.
*/

import 'package:flutter/material.dart';

import 'color_ex.dart';
import 'hmb_chip.dart';

class HMBMenuChip<T> extends StatelessWidget {
  const HMBMenuChip({
    required this.label,
    required this.values,
    required this.format,
    required this.onSelected,
    super.key,
    this.tone = HMBChipTone.neutral,
    this.icon,
    this.enabled = true,
    this.tooltip,
    this.offset = const Offset(0, 8),
    this.itemIcon, // optional: icon per value
    this.itemEnabled, // optional: enable/disable per value
  });

  final String label;
  final List<T> values;
  final String Function(T value) format;
  final ValueChanged<T> onSelected;

  final HMBChipTone tone;
  final IconData? icon;
  final bool enabled;
  final String? tooltip;
  final Offset offset;

  /// Optional builders for popup rows
  final IconData? Function(T value)? itemIcon;
  final bool Function(T value)? itemEnabled;

  @override
  Widget build(BuildContext context) {
    final bg = _bgColor(context);
    final fg = _fgColor(context);

    final chipChild = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.arrow_drop_down, size: 18, color: fg),
      ],
    );

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: chipChild,
    );

    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<T>(
        enabled: enabled,
        tooltip: tooltip,
        offset: offset,
        padding: EdgeInsets.zero,
        elevation: 3,
        onSelected: onSelected,
        itemBuilder: (context) => values.map((v) {
          final enabled = itemEnabled?.call(v) ?? true;
          final leading = itemIcon?.call(v);
          return PopupMenuItem<T>(
            value: v,
            enabled: enabled,
            child: Row(
              children: [
                if (leading != null) ...[
                  Icon(leading, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(format(v))),
              ],
            ),
          );
        }).toList(),
        child: chip,
      ),
    );
  }

  Color _bgColor(BuildContext context) {
    switch (tone) {
      case HMBChipTone.accent:
        return Theme.of(context).colorScheme.primary.withSafeOpacity(0.15);
      case HMBChipTone.danger:
        return Colors.red.withSafeOpacity(0.15);
      case HMBChipTone.warning:
        return Colors.orange.withSafeOpacity(0.15);
      case HMBChipTone.neutral:
        final c = Theme.of(context).chipTheme.backgroundColor;
        return (c ?? Colors.grey).withSafeOpacity(0.15);
    }
  }

  Color _fgColor(BuildContext context) {
    switch (tone) {
      case HMBChipTone.accent:
        return Colors.white;
      case HMBChipTone.danger:
        return Colors.red.shade400;
      case HMBChipTone.warning:
        return Colors.orange.shade700;
      case HMBChipTone.neutral:
        return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white;
    }
  }
}
