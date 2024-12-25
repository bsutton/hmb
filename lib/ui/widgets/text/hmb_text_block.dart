import 'package:flutter/material.dart';

import '../../../util/hmb_theme.dart';

class HMBTextBlock extends StatelessWidget {
  /// If [verticalPadding] is true, vertical padding is added before the text.
  const HMBTextBlock(
    this.labelText, {
    super.key,
    this.verticalPadding = true,
    this.bold = false,
    this.underline = false,
    this.maxLines = 3,
    Color? color,
  }) : color = color ?? HMBColors.textPrimary;

  final String labelText;
  final bool verticalPadding;
  final bool bold;
  final bool underline;
  final int maxLines;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: verticalPadding ? 8.0 : 0.0),
        child: Text(
          labelText,
          softWrap: true,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
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
