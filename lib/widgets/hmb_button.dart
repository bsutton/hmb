import 'package:flutter/material.dart';

class HMBButton extends StatelessWidget {
  const HMBButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      );
}
