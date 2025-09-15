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

class HMBTextArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final int maxLines;
  final bool leadingPadding;
  final void Function(String?)? onChanged;

  const HMBTextArea({
    required this.controller,
    required this.labelText,
    this.onChanged,
    this.maxLines = 6,
    this.focusNode,
    this.leadingPadding = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (leadingPadding) const SizedBox(height: 16),
      TextFormField(
        maxLines: maxLines,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged?.call,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
      ),
    ],
  );
}
