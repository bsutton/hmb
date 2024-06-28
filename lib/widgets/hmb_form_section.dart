import 'package:flutter/material.dart';

class HMBFormSection extends StatelessWidget {
  const HMBFormSection(
      {required this.children, super.key, this.leadingSpace = true});

  final bool leadingSpace;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children)));
}
