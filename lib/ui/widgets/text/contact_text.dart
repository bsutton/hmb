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

import '../../../entity/contact.dart';
import '../../../util/hmb_theme.dart';

class ContactText extends StatelessWidget {
  final String label;
  final Contact? contact;

  const ContactText({required this.label, required this.contact, super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(4),
    child: Row(
      children: [
        if (contact != null)
          Text(label, style: const TextStyle(color: HMBColors.textPrimary)),
        if (contact != null)
          Text(
            '${contact?.firstName} ${contact?.surname}',
            style: const TextStyle(color: HMBColors.textPrimary),
          ),
      ],
    ),
  );
}
