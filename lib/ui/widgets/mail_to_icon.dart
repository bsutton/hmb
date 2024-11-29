import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:mailto/mailto.dart';
import 'package:strings/strings.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../util/clip_board.dart';
import 'hmb_toast.dart';

class MailToIcon extends StatelessWidget {
  const MailToIcon(this.email, {super.key});
  final String? email;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // added line
        mainAxisSize: MainAxisSize.min, // added
        children: [
          IconButton(
            iconSize: 22,
            icon: const Icon(Icons.email),
            onPressed: () async =>
                Strings.isEmpty(email) ? null : _sendEmail(context, email!),
            color: Strings.isEmpty(email) ? Colors.grey : Colors.blue,
            tooltip: 'Send an Email',
          ),
          IconButton(
            iconSize: 22,
            icon: const Icon(Icons.copy),
            onPressed: () async => Strings.isEmpty(email)
                ? null
                : clipboardCopyTo(context, email!),
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
      final mailtoLink = Mailto(
        to: [email],
      );
      await launchUrlString(mailtoLink.toString());
    }
  }
}
