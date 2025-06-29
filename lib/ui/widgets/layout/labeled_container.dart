/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

class LabeledContainer extends StatelessWidget {
  const LabeledContainer({
    required this.labelText,
    required this.child,
    required this.backgroundColor,
    this.isError = false,
    super.key,
  });
  final String labelText;
  final Widget child;
  final bool isError;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none, // Allow overflow for the Positioned widget
    children: [
      Container(
        margin: const EdgeInsets.only(top: 20), // Adjust to prevent clipping
        decoration: BoxDecoration(
          border: Border.all(
            color: isError ? Theme.of(context).colorScheme.error : Colors.grey,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
      Positioned(
        top: 8,
        left: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          color: backgroundColor,
          child: Text(
            labelText,
            style: TextStyle(
              fontSize: 13,
              color: isError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.black,
            ),
          ),
        ),
      ),
    ],
  );
}
