/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

class HMBSpacer extends StatelessWidget {
  const HMBSpacer({this.width = false, this.height = false, super.key});
  final bool width;
  final bool height;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: width ? 16.0 : null, height: height ? 16.0 : null);
}
