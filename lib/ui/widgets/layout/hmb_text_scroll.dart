/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

class HMBScrollText extends StatelessWidget {
  const HMBScrollText({required this.text, this.maxHeight = 300, super.key});

  final String text;
  final double maxHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight, // Set your maximum height here
      ),
      child: SingleChildScrollView(
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    ),
  );
}
