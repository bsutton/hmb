import 'package:flutter/material.dart';

import '../../../util/hmb_theme.dart';

class HMBText extends StatelessWidget {
  /// If [verticalPadding] is true, vertical padding is added before the text.
  const HMBText(
    this.labelText, {
    super.key,
    this.verticalPadding = true,
    this.bold = false,
    this.underline = false,
    Color? color,
  }) : color = color ?? HMBColors.textPrimary;

  final String labelText;
  final bool verticalPadding;
  final bool bold;
  final bool underline;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: verticalPadding ? 8.0 : 0.0),
    child: Text(
      labelText,
      softWrap: true,
      style: TextStyle(
        fontSize: 14,
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        decoration: underline ? TextDecoration.underline : TextDecoration.none,
      ),
    ),
  );
}
