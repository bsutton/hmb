/*
 Copyright © OnePub IP Pty Ltd.
 All Rights Reserved.
*/

import 'package:flutter/material.dart';

import 'color_ex.dart';
import 'hmb_chip.dart';

/// Generic chip selector that works for enums or any value type.
///
/// Example:
/// ```dart
/// HMBSelectChips<ToDoPriority>(
///   label: 'Priority',
///   value: _priority,
///   items: ToDoPriority.values,
///   toText: (v) => v.name,
///   onChanged: (v) => setState(() => _priority = v!),
/// )
/// ```
class HMBSelectChips<T> extends StatelessWidget {
  const HMBSelectChips({
    required this.label,
    required this.items,
    required this.value,
    required this.format,
    required this.onChanged,
    super.key,
    this.tone = HMBChipTone.neutral,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
  });

  final String label;
  final List<T> items;
  final T? value;
  final String Function(T) format;
  final ValueChanged<T?> onChanged;
  final HMBChipTone tone;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: items.map((item) {
          final selected = value == item;
          return ChoiceChip(
            label: Text(format(item)),
            selected: selected,
            onSelected: (_) => onChanged(item),
            checkmarkColor: Colors.white,
            selectedColor: _selectedColor(context),
            labelStyle: TextStyle(
              color: selected
                  ? _selectedTextColor(context)
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
            backgroundColor: Theme.of(
              context,
            ).chipTheme.backgroundColor?.withSafeOpacity(0.15),
            shape: const StadiumBorder(
              side: BorderSide(color: Colors.white, width: 1.5),
            ),
          );
        }).toList(),
      ),
    ],
  );

  Color _selectedColor(BuildContext context) {
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

  Color _selectedTextColor(BuildContext context) {
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
}
