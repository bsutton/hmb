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
  }) {
    this.color = color ??= Colors.grey[700];
  }
  final String labelText;
  final bool verticalPadding;
  final bool bold;
  late final Color? color;

  @override
  Widget build(BuildContext context) => Row(children: [
        Column(
          children: [
            if (verticalPadding) const SizedBox(height: 8),
            Text(
              labelText,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ]);
}
