import 'package:flutter/material.dart';
import '../widgets.g.dart';

class HMBPadding extends StatelessWidget {
  const HMBPadding({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Surface(child: child),
    );
  }
}
