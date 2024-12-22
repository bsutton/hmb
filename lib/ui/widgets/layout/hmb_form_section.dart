import 'package:flutter/material.dart';

import '../surface.dart';

class HMBFormSection extends StatelessWidget {
  const HMBFormSection(
      {required this.children, super.key, this.leadingSpace = true});

  final bool leadingSpace;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Surface(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children)));
}
