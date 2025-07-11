/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:mailto/mailto.dart';
import 'package:strings/strings.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../util/clip_board.dart';
import 'hmb_toast.dart';

class HMBMailToIcon extends StatelessWidget {
  const HMBMailToIcon(this.email, {super.key});
  final String? email;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween, // added line
    mainAxisSize: MainAxisSize.min, // added
    children: [
      IconButton(
        iconSize: 22,
        icon: const Icon(Icons.email),
        onPressed: () => Strings.isEmpty(email)
            ? null
            : unawaited(_sendEmail(context, email!)),
        color: Strings.isEmpty(email) ? Colors.grey : Colors.blue,
        tooltip: 'Send an Email',
      ),
      IconButton(
        iconSize: 22,
        icon: const Icon(Icons.copy),
        onPressed: () =>
            Strings.isEmpty(email) ? null : unawaited(clipboardCopyTo(email!)),
        color: Strings.isEmpty(email) ? Colors.grey : Colors.blue,
        tooltip: 'Copy Email address to the Clipboard',
      ),
    ],
  );

  Future<void> _sendEmail(BuildContext context, String email) async {
    email = email.trim();
    if (!EmailValidator.validate(email)) {
      HMBToast.error("Invalid email address '$email'");
    } else {
      final mailtoLink = Mailto(to: [email]);
      await launchUrlString(mailtoLink.toString());
    }
  }
}
