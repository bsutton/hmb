import 'package:flutter/material.dart';

import '../widgets.g.dart';

class HMBPadding extends StatelessWidget {
  const HMBPadding({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Surface(child: child),
  );
}
