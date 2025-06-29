/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import 'hmb_text.dart';

class HMBTextClickable extends StatelessWidget {
  const HMBTextClickable({
    required this.text,
    required this.onPressed,
    this.bold = false,
    this.color = Colors.blue,
    super.key,
  });
  final String text;
  final VoidCallback onPressed;
  final bool bold;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HMBText(text, bold: bold, underline: true),
    ),
  );
}
