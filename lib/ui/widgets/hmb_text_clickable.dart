import 'package:flutter/material.dart';

import 'text/hmb_text.dart';

class HMBTextClickable extends StatelessWidget {
  const HMBTextClickable({
    required this.text,
    required this.onPressed,
    this.bold = false,
    this.color = Colors.blue,
    super.key,
  });
  final String text;
  final VoidCallback onPressed;
  final bool bold;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: HMBText(
            text,
            bold: bold,
            underline: true,
          ),
        ),
      );
}
