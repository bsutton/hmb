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

import 'layout/layout.g.dart';

class HMBSwitch extends StatelessWidget {
  final bool? initialValue;
  final FocusNode? focusNode;
  final String labelText;
  final bool autofocus;
  final bool leadingSpace;

  // ignore: avoid_positional_boolean_parameters
  final void Function(bool newValue) onChanged;

  const HMBSwitch({
    required this.labelText,
    required this.initialValue,
    required this.onChanged,
    this.autofocus = false,
    this.focusNode,
    super.key,
    this.leadingSpace = true,
  });

  @override
  Widget build(BuildContext context) => HMBColumn(
    leadingSpace: leadingSpace,
    children: [
      SwitchListTile(
        focusNode: focusNode,
        title: Text(labelText),
        value: initialValue ?? false,
        onChanged: onChanged,
      ),
    ],
  );
}
