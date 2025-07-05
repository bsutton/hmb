import 'package:flutter/material.dart';

import '../hmb_button.dart';

/// A bottom sheet wrapper that displays dynamic filter content.
///
/// Use [contentBuilder] to supply the sheet's form fields or widgets.
class HMBFilterSheet extends StatelessWidget {
  const HMBFilterSheet({
    required this.contentBuilder,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.onClearAll,
  });

  /// Content builder for the sheet body
  final WidgetBuilder contentBuilder;

  /// Padding around sheet content
  final EdgeInsets padding;

  /// Callback to clear all filters; if provided, a "Clear All" button is shown
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: padding.left,
      right: padding.right,
      top: padding.top,
      bottom: MediaQuery.of(context).viewInsets.bottom + padding.bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // dynamic filter fields
        contentBuilder(context),

        // optional clear-all button
        if (onClearAll != null) ...[
          const SizedBox(height: 16),
          // alignment: Alignment.centerRight,
          SizedBox(
            width: double.infinity,
            child: HMBButtonPrimary(
              onPressed: () => onClearAll?.call(),
              label: 'Clear All',
              hint: 'Clear all search filters',
            ),
          ),
        ],
      ],
    ),
  );
}
