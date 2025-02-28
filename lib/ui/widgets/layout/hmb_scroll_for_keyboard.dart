import 'package:flutter/material.dart';


/// Used in forms to ensure that the user can always
/// scroll to every field when the keyboard is displayed.
/// 
class HMBScrollForKeyboard extends StatelessWidget {
  const HMBScrollForKeyboard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SingleChildScrollView(child: child),
  );
}
