import 'package:flutter/material.dart';

import 'hmb_filter_sheet.dart';

typedef BoolCallback = bool Function();

/// A single filter line widget with an associated
/// sheet for additional advanced filter options.
///
/// The widget returned by [lineBuilder] is shown on the left
/// and a filter icon button on the right.
///
/// If the users clicks the filter button then a bottom sheet is
/// displayed with the content of [sheetBuilder]
class HMBFilterLine extends StatelessWidget {
  const HMBFilterLine({
    required this.lineBuilder,
    required this.sheetBuilder,
    required this.onReset,
    required this.isActive,
    this.onSheetClosed,
    super.key,
    this.tooltip = 'Filter',
  });

  /// Builds the left-hand content area
  final WidgetBuilder lineBuilder;
  final WidgetBuilder sheetBuilder;
  final VoidCallback? onReset;
  final VoidCallback? onSheetClosed;

  /// Whether filter is currently active (affects icon)
  final BoolCallback isActive;

  /// Called when the filter icon is pressed
  // final VoidCallback onFilterTap;

  /// Icon when filter is inactive
  static const IconData icon = Icons.tune;

  /// Tooltip for the icon button
  final String tooltip;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      // left content
      Expanded(child: lineBuilder(context)),
      IconButton(
        icon: const Icon(icon),
        tooltip: tooltip,
        color: isActive() ? Colors.blue : Colors.grey,

        onPressed: () async {
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) =>
                HMBFilterSheet(contentBuilder: sheetBuilder, onReset: onReset),
          );
          onSheetClosed?.call();
        },
      ),
    ],
  );
}
