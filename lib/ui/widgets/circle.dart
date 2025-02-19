import 'package:flutter/material.dart';

class Circle extends StatelessWidget {
  const Circle({
    required this.child,
    super.key,
    this.color = Colors.white,
    this.diameter = 20,
    this.shadow = false,
  });
  final double diameter;
  final Widget child;
  final Color color;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    if (shadow) {
      return Material(
        shape: const StadiumBorder(),
        elevation: 7,
        child: Container(
          height: diameter,
          width: diameter,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(diameter / 2),
          ),
          child: Center(child: child),
        ),
      );
    } else {
      return Container(
        height: diameter,
        width: diameter,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(diameter / 2),
        ),
        child: Center(child: child),
      );
    }
  }
}
