// lib/src/widgets/desktop_back_gesture.dart

import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps [child] with keyboard, mouse-button and swipe-back handlers,
/// using a provided [navigatorKey] to pop the correct Navigator from GoRouter.
///
/// On desktop it will respond to:
///  • Alt+←
///  • Backspace
///  • "BrowserBack" key
///  • Mouse thumb “back” button
///  • Horizontal drag to the right
///
/// Usage:
/// ```dart
/// // 1. Create a root navigator key
/// final _rootNavigatorKey = GlobalKey<NavigatorState>();
///
/// // 2. Pass it into your GoRouter
/// final router = GoRouter(
///   navigatorKey: _rootNavigatorKey,
///   routes: [ /* your routes here */ ],
/// );
///
/// // 3. Wrap your MaterialApp.router's builder
/// MaterialApp.router(
///   routerConfig: router,
///   builder: (context, child) => DesktopBackGesture(
///     navigatorKey: _rootNavigatorKey,
///     child: child!,
///   ),
/// );
/// ```
class DesktopBackGesture extends StatelessWidget {
  const DesktopBackGesture({
    required this.child,
    required this.navigatorKey,
    super.key,
  });

  /// The widget subtree containing your app's Router/Navigator
  final Widget child;

  /// The same GlobalKey passed into GoRouter
  final GlobalKey<NavigatorState> navigatorKey;

  /// Mouse button code for "Back" (thumb button)
  static const int kBackMouseButton = 8;

  /// Threshold for horizontal drag to count as a "back" swipe
  static const double _dragThreshold = 20;

  bool _shouldPop(NavigatorState? nav) => nav != null && nav.canPop();

  @override
  Widget build(BuildContext context) => KeyboardListener(
    focusNode: FocusNode(),
    autofocus: true,
    onKeyEvent: (event) {
      if (event is KeyDownEvent) {
        final nav = navigatorKey.currentState;
        final key = event.logicalKey;
        // Alt + Left Arrow
        if (key == LogicalKeyboardKey.arrowLeft &&
            HardwareKeyboard.instance.isAltPressed) {
          if (_shouldPop(nav)) {
            nav!.pop();
          }
        } else if (key == LogicalKeyboardKey.backspace ||
            key == LogicalKeyboardKey.goBack) {
          // Backspace or BrowserBack
          if (_shouldPop(nav)) {
            nav!.pop();
          }
        }
      }
    },
    child: Listener(
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse &&
            event.buttons == kBackMouseButton) {
          final nav = navigatorKey.currentState;
          if (_shouldPop(nav)) {
            nav!.pop();
          }
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          // Negative dx for right-to-left swipe (back)
          if (details.delta.dx < -_dragThreshold) {
            final nav = navigatorKey.currentState;
            if (_shouldPop(nav)) {
              nav!.pop();
            }
          }
        },
        child: child,
      ),
    ),
  );
}
