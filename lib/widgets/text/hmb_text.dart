import 'package:flutter/material.dart';

class HMBText extends StatelessWidget {
  /// If [verticalPadding] is true then vertical padding
  /// is added before the text.
  HMBText(
    this.labelText, {
    super.key,
    this.verticalPadding = true,
    this.bold = false,
    Color? color,
  }) : color = color ?? Colors.grey[700];

  final String labelText;
  final bool verticalPadding;
  final bool bold;
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
          ),
        ),
      );
}
