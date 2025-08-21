/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/widgets.dart';

typedef OnSwipe = void Function();

class HMBSwipeLeft extends StatelessWidget {
  final Widget child;
  final OnSwipe onSwipe;

  const HMBSwipeLeft({required this.child, required this.onSwipe, super.key});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onHorizontalDragEnd: (details) {
      // Check if the swipe is from left to right
      if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
        onSwipe();
      }
    },
    child: child,
  );
}
