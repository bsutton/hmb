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

class HMBLinkInternal extends StatelessWidget {
  final String label;
  final Future<Widget> Function() navigateTo;
  final Future<void> Function()? onReturned;
  final int? maxLines;
  final TextOverflow? overflow;

  const HMBLinkInternal({
    required this.label,
    required this.navigateTo,
    this.onReturned,
    this.maxLines,
    this.overflow,
    super.key,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final widget = await navigateTo();
      if (context.mounted) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (context) => widget));
        if (onReturned != null) {
          await onReturned!();
        }
      }
    },
    child: Text(
      label,
      maxLines: maxLines,
      overflow: overflow,
      style: const TextStyle(
        color: Colors.green,
        decoration: TextDecoration.underline,
      ),
    ),
  );
}
