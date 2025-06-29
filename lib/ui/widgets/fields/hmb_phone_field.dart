/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../dialog/source_context.dart';
import '../hmb_phone_icon.dart';

class HMBPhoneField extends StatelessWidget {
  const HMBPhoneField({
    required this.labelText,
    required this.controller,
    required this.sourceContext,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String labelText;
  final String? Function(String? value)? validator;
  final SourceContext sourceContext;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.phone,
    decoration: InputDecoration(
      labelText: labelText,
      suffixIcon: HMBPhoneIcon(controller.text, sourceContext: sourceContext),
    ),
    validator: validator,
  );
}
