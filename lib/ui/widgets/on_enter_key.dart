import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Captures the enter key and calls [onPressed]
class OnEnterKey extends StatelessWidget {
  const OnEnterKey({
    required this.context,
    required this.child,
    required this.onPressed,
    super.key,
  });

  final BuildContext context;
  final Widget child;
  final void Function(BuildContext context) onPressed;

  @override
  Widget build(BuildContext context) => KeyboardListener(
        focusNode: FocusNode(), // Ensure that the RawKeyboardListener
        // receives key events
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            // Handle Enter key press here
            // For example, call onPressed for the RaisedButton
            onPressed(context);
          }
        },
        child: child,
      );
}
