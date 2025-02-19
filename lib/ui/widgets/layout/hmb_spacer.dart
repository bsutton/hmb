import 'package:flutter/material.dart';

class HMBSpacer extends StatelessWidget {
  const HMBSpacer({this.width = false, this.height = false, super.key});
  final bool width;
  final bool height;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: width ? 16.0 : null, height: height ? 16.0 : null);
}
