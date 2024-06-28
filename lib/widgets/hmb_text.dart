import 'package:flutter/material.dart';

class HMBText extends StatelessWidget {
  const HMBText(
    this.labelText, {
    super.key,
    this.leadingSpace = true,
  });
  final String labelText;
  final bool leadingSpace;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (leadingSpace) const SizedBox(height: 8),
          Text(
            labelText,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ],
      );
}
