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
import 'package:money2/money2.dart';

import '../layout/layout.g.dart';

class HMBFixed extends StatelessWidget {
  final String label;
  final bool verticalPadding;
  final Fixed? amount;

  const HMBFixed({
    required this.label,
    required this.amount,
    super.key,
    this.verticalPadding = true,
  });

  @override
  Widget build(BuildContext context) => HMBColumn(
    leadingSpace: verticalPadding,
    children: [
      Text(
        '$label $amount',
        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
      ),
    ],
  );
}
