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

import '../widgets/layout/layout.g.dart';

class HMBDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget>? actions;
  final EdgeInsets insetPadding;
  final EdgeInsets titlePadding;
  final EdgeInsets contentPadding;

  const HMBDialog({
    required this.title,
    required this.content,
    super.key,
    this.actions,
    this.insetPadding = const EdgeInsets.all(8), // Default padding to 0
    this.titlePadding = const EdgeInsets.all(8),
    this.contentPadding = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: insetPadding,
    // Controls the padding outside the dialog
    child: Padding(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: HMBColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            AlertDialog(
              titlePadding: titlePadding,
              contentPadding: contentPadding,
              insetPadding: EdgeInsets.zero,
              title: title,
              content: content,
              actions: actions,
            ),
          ],
        ),
      ),
    ),
  );
}
