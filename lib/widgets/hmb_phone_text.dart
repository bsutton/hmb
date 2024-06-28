import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../util/plus_space.dart';
import 'dial_widget.dart';

/// Displays the label and phoneNum.
/// If the phoneNum is null then we display nothing.
class HMBPhoneText extends StatelessWidget {
  const HMBPhoneText({required this.phoneNo, this.label, super.key});
  final String? label;
  final String? phoneNo;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (Strings.isNotBlank(phoneNo)) Text('${plusSpace(label)} $phoneNo'),
          if (Strings.isNotBlank(phoneNo)) DialWidget(phoneNo!)
        ],
      );
}
