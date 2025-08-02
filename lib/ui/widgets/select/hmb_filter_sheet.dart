import 'package:flutter/material.dart';

import '../hmb_button.dart';

/// A bottom sheet wrapper that displays dynamic filter content.
///
/// Use [contentBuilder] to supply the sheet's form fields or widgets.
class HMBFilterSheet extends StatefulWidget {
  const HMBFilterSheet({
    required this.contentBuilder,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.onReset,
  });

  /// Content builder for the sheet body
  final WidgetBuilder contentBuilder;

  /// Padding around sheet content
  final EdgeInsets padding;

  /// Callback to reset  filters to their original state; if provided, a "Reset" button is shown
  final VoidCallback? onReset;

  @override
  State<HMBFilterSheet> createState() => _HMBFilterSheetState();
}

class _HMBFilterSheetState extends State<HMBFilterSheet> {
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: widget.padding.left,
      right: widget.padding.right,
      top: widget.padding.top,
      bottom: MediaQuery.of(context).viewInsets.bottom + widget.padding.bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // dynamic filter fields
        widget.contentBuilder(context),

        // optional clear-all button
        if (widget.onReset != null) ...[
          const SizedBox(height: 16),
          // alignment: Alignment.centerRight,
          SizedBox(
            width: double.infinity,
            child: HMBButtonPrimary(
              onPressed: () {
                widget.onReset?.call();
                setState(() {});
              },
              label: 'Reset All',
              hint: 'Reset filters to their default',
            ),
          ),
        ],
      ],
    ),
  );
}
