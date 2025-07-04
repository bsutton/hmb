/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Supports swipping left/right as well
/// as using arrow keys (left/right) and the home
/// key to navigate horizontally across pages.
/// The guesture detection on linux is flakey
/// you have to swipe really fast with the mouse
/// for it to work.
class DesktopSwipe extends StatelessWidget {
  const DesktopSwipe({
    required this.child,
    required this.onHome,
    required this.onNext,
    required this.onPrevious,
    super.key,
  });

  final Widget child;

  final void Function() onHome;
  final void Function() onNext;
  final void Function() onPrevious;

  @override
  Widget build(BuildContext context) =>
      /// support left/right arrows.
      Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              onNext();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              onPrevious();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.home) {
              onHome();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child:
            /// support swipe left/right
            GestureDetector(
              onHorizontalDragEnd: (details) {
                print(
                  'horizontal drag: velocity: ${details.primaryVelocity}, ${details.velocity}',
                );
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! < 0) {
                    onNext();
                  } else if (details.primaryVelocity! > 0) {
                    onPrevious();
                  }
                }
              },
              child: child,
            ),
      );
}
