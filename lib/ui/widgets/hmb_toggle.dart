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

import 'text/hmb_text_themes.dart';

// ignore: avoid_positional_boolean_parameters
typedef OnToggled = void Function(bool on);

class HMBToggle extends StatefulWidget {
  final String label;
  final bool initialValue;
  final String hint;
  final OnToggled onToggled;

  const HMBToggle({
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onToggled,
    super.key,
  });

  @override
  State<HMBToggle> createState() => _HMBToggleState();
}

class _HMBToggleState extends State<HMBToggle> {
  late bool on;
  @override
  void initState() {
    on = widget.initialValue;
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      HMBTextLabel(widget.label),
      IconButton(
        tooltip: widget.hint,
        onPressed: () {
          setState(() {
            on = !on;
            widget.onToggled(on);
          });
        },
        iconSize: 25,
        icon: Icon(on ? Icons.toggle_on : Icons.toggle_off),
      ),
    ],
  );
}
