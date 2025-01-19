import 'package:flutter/material.dart';
import '../../../util/hmb_theme.dart';

/// Displays a multi-line block of text that expands/contracts
/// based on content.
class HMBExpandingTextBlock extends StatelessWidget {
  /// If [verticalPadding] is true, vertical padding is added before the text.
  const HMBExpandingTextBlock(
    this.textBlock, {
    super.key,
    this.verticalPadding = true,
    this.bold = false,
    this.underline = false,
    Color? color,
  }) : color = color ?? HMBColors.textPrimary;

  final String textBlock;
  final bool verticalPadding;
  final bool bold;
  final bool underline;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: verticalPadding ? 8.0 : 0.0),
        child: Text(
          textBlock,
          softWrap: true,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            decoration:
                underline ? TextDecoration.underline : TextDecoration.none,
          ),
        ),
      );
}
