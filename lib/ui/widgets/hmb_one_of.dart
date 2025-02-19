import 'package:flutter/material.dart';

/// Display one or another widget based on a condition.
/// If [condition] is true, [onTrue] is displayed,
///  otherwise [onFalse] is displayed.
class HMBOneOf extends StatelessWidget {
  const HMBOneOf({
    required this.condition,
    required this.onTrue,
    required this.onFalse,
    super.key,
  });

  final bool condition;
  final Widget onTrue;
  final Widget onFalse;

  @override
  Widget build(BuildContext context) => condition ? onTrue : onFalse;
}
