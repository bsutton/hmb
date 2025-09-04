/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/widgets/desktop_back_gesture.dart

import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:june/june.dart';

import '../../util/flutter/platform_ex.dart';
import 'desktop_back_gesture_suppress.dart';

/// Provides back navigation on Desktop.
///
/// Wraps [child] with keyboard, mouse-button and edge-swipe back handlers.
/// Uses a provided [navigatorKey] to pop the correct Navigator.
///
/// On desktop it responds to:
///  • Alt+←
///  • "BrowserBack" key
///  • Mouse thumb “back” button
///  • Edge (left) swipe to the right
/// /// Usage:
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
class DesktopBackGesture extends StatefulWidget {
  /// Mouse button bit for "Back" (thumb button).
  static const kBackMouseButton = 8;

  /// How far the pointer must move (px) from the drag start to count as back.
  static const double kDragDistanceThreshold = 40;

  /// Only start tracking a back-swipe if touch starts within this edge width.
  static const double kEdgeWidth = 24;

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  /// Active only on non-mobile devices.
  final bool swipeDetectionIsActive;

  DesktopBackGesture({
    required this.child,
    required this.navigatorKey,
    super.key,
  }) : swipeDetectionIsActive = isNotMobile;

  @override
  State<DesktopBackGesture> createState() => _DesktopBackGestureState();
}

class _DesktopBackGestureState extends State<DesktopBackGesture> {
  final _focusNode = FocusNode(debugLabel: 'DesktopBackGesture');
  double? _dragStartDx;
  var _trackingEdgeSwipe = false;

  NavigatorState? get _nav => widget.navigatorKey.currentState;

  Future<void> _maybePop() async {
    if (_nav != null) {
      // maybePop respects WillPopScope and route guards.
      await _nav!.maybePop();
    }
  }

  bool get _isSuppressed => June.getState(IgnoreDesktopGesture.new).ignored;

  // --- Keyboard shortcuts (no manual key event plumbing needed) ---
  Map<ShortcutActivator, Intent> get _shortcuts => <ShortcutActivator, Intent>{
    // Alt + Left Arrow
    const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
        const ActivateIntent(),
    // BrowserBack key (some keyboards)
    const SingleActivator(LogicalKeyboardKey.goBack): const ActivateIntent(),
  };

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If gesture handling is disabled or suppressed, just return the child.
    if (!widget.swipeDetectionIsActive || _isSuppressed) {
      return widget.child;
    }

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<Intent>(
            onInvoke: (intent) async {
              await _maybePop();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          focusNode: _focusNode,
          child: Listener(
            // Mouse back (thumb) button.
            onPointerDown: (event) async {
              if (event.kind == PointerDeviceKind.mouse) {
                final buttons = event.buttons;
                const back = DesktopBackGesture.kBackMouseButton;
                if ((buttons & back) != 0) {
                  await _maybePop();
                }
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior
                  .deferToChild, // don't steal from children prematurely
              onHorizontalDragStart: (details) {
                final dx = details.globalPosition.dx;
                _dragStartDx = dx;
                _trackingEdgeSwipe = dx <= DesktopBackGesture.kEdgeWidth;
              },
              onHorizontalDragUpdate: (details) async {
                if (!_trackingEdgeSwipe || _dragStartDx == null) {
                  return;
                }
                // Back gesture: edge-left swipe to the RIGHT (positive delta).
                final travelled = details.globalPosition.dx - _dragStartDx!;
                if (travelled >= DesktopBackGesture.kDragDistanceThreshold) {
                  _trackingEdgeSwipe = false; // one-shot
                  _dragStartDx = null;
                  await _maybePop();
                }
              },
              onHorizontalDragEnd: (_) {
                _trackingEdgeSwipe = false;
                _dragStartDx = null;
              },
              onHorizontalDragCancel: () {
                _trackingEdgeSwipe = false;
                _dragStartDx = null;
              },
              child: JuneBuilder(
                IgnoreDesktopGesture.new,
                builder: (context) => widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
