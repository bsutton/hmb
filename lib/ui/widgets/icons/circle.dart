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

import 'package:flutter/material.dart';

class Circle extends StatelessWidget {
  final double diameter;
  final Widget child;
  final Color color;
  final bool shadow;

  const Circle({
    required this.child,
    super.key,
    this.color = Colors.white,
    this.diameter = 20,
    this.shadow = false,
  });

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
