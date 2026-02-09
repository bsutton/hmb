import 'package:flutter/material.dart';

class HMBPadding extends StatelessWidget {
  final Widget child;

  const HMBPadding({required this.child, super.key});

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(8), child: child);
}
