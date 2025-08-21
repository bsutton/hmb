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

/// Display one or another widget based on a condition.
/// If [condition] is true, [onTrue] is displayed,
///  otherwise [onFalse] is displayed.
class HMBOneOf extends StatelessWidget {
  final bool condition;
  final Widget onTrue;
  final Widget onFalse;

  const HMBOneOf({
    required this.condition,
    required this.onTrue,
    required this.onFalse,
    super.key,
  });

  @override
  Widget build(BuildContext context) => condition ? onTrue : onFalse;
}
