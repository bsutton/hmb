import 'package:flutter/material.dart';

import 'hmb_filter_sheet.dart';

/// A single filter line widget showing custom content on the left
/// and a filter icon button on the right.
///
/// [builder] should return the widget (e.g., a TextField or dropdown)
/// to place on the left side.
class HMBFilterLine extends StatelessWidget {
  const HMBFilterLine({
    required this.lineBuilder,
    required this.sheetBuilder,
    required this.onClearAll,

    // required this.onFilterTap,
    super.key,
    this.icon = Icons.tune,
    this.isActive = false,
    this.tooltip = 'Filter',
  });

  /// Builds the left-hand content area
  final WidgetBuilder lineBuilder;
  final WidgetBuilder sheetBuilder;
  final VoidCallback? onClearAll;

  /// Called when the filter icon is pressed
  // final VoidCallback onFilterTap;

  /// Icon when filter is inactive
  final IconData icon;

  /// Whether filter is currently active (affects icon)
  final bool isActive;

  /// Tooltip for the icon button
  final String tooltip;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      // left content
      Expanded(child: lineBuilder(context)),
      IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: () async {
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => HMBFilterSheet(
              contentBuilder: sheetBuilder,
              onClearAll: onClearAll,
            ),
          );
        },
      ),
    ],
  );
}
