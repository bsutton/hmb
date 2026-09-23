import 'package:material_ui/material_ui.dart';

import '../../../util/flutter/hmb_theme.dart';
import '../hmb_search.dart';
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
class HMBFilterLine extends StatefulWidget {
  /// Icon when filter is inactive
  static const IconData icon = Icons.tune;

  /// Builds the left-hand content area
  final WidgetBuilder lineBuilder;
  final WidgetBuilder sheetBuilder;
  final VoidCallback? onReset;
  final VoidCallback? onSheetClosed;

  /// Whether filter is currently active (affects icon)
  final BoolCallback isActive;

  /// Tooltip for the icon button
  final String tooltip;

  const HMBFilterLine({
    required this.lineBuilder,
    required this.sheetBuilder,
    required this.onReset,
    required this.isActive,
    this.onSheetClosed,
    super.key,
    this.tooltip = 'Filter',
  });

  @override
  State<HMBFilterLine> createState() => _HMBFilterLineState();
}

class _HMBFilterLineState extends State<HMBFilterLine> {
  var _searchFocused = false;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<HMBSearchFocusNotification>(
        onNotification: (notification) {
          setState(() => _searchFocused = notification.focused);
          return false;
        },
        child: Row(
          children: [
            // left content
            Expanded(child: widget.lineBuilder(context)),
            if (!_searchFocused)
              IconButton(
                icon: const Icon(HMBFilterLine.icon),
                tooltip: widget.tooltip,
                color: widget.isActive() ? HMBColors.primary : Colors.grey,
                onPressed: () async {
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => HMBFilterSheet(
                      contentBuilder: widget.sheetBuilder,
                      onReset: widget.onReset,
                    ),
                  );
                  widget.onSheetClosed?.call();
                },
              ),
          ],
        ),
      );
}
