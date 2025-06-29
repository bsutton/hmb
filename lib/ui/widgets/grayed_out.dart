/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

/// GreyedOut optionally grays out the given child widget.
/// [child] the child widget to display
/// If [grayedOut] is true then the child will be grayed out and
/// any touch activity over the child will be discarded.
/// If [grayedOut] is false then the child will displayed as normal.
/// The [grayedOut] setting controls the visiblity of the child
/// when it is greyed out. A value of 1.0 makes the child fully visible,
/// a value of 0.0 makes the child fully opaque.
/// The default value of [opacity] is 0.3.
class GrayedOut extends StatelessWidget {
  const GrayedOut({required this.child, super.key, this.grayedOut = true})
    : opacity = grayedOut ? 0.3 : 1.0;
  final Widget child;
  final bool grayedOut;
  final double opacity;

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    absorbing: grayedOut,
    child: Opacity(opacity: opacity, child: child),
  );
}
