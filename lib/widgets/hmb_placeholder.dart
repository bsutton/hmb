import 'package:flutter/material.dart';

class HMBPlaceHolder extends StatelessWidget {
  const HMBPlaceHolder({
    this.width,
    this.height,
    super.key,
  });
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
      );
}
