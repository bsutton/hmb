import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../widgets/hmb_button.dart';

bool includesOwnEmail({
  required String? ownEmail,
  required Iterable<String> recipients,
}) {
  final normalizedOwnEmail = ownEmail?.trim().toLowerCase();
  if (Strings.isBlank(normalizedOwnEmail)) {
    return false;
  }

  return recipients
      .map((email) => email.trim().toLowerCase())
      .contains(normalizedOwnEmail);
}

class EmailSelfWarning extends StatelessWidget {
  final String? ownEmail;
  final Iterable<String> recipients;

  const EmailSelfWarning({
    required this.ownEmail,
    required this.recipients,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!includesOwnEmail(ownEmail: ownEmail, recipients: recipients)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        border: Border.all(color: Colors.amber.shade700),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are sending this email to your own address ($ownEmail).',
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmSendingToSelf({
  required BuildContext context,
  required String? ownEmail,
  required Iterable<String> recipients,
}) async {
  if (!includesOwnEmail(ownEmail: ownEmail, recipients: recipients)) {
    return true;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sending to yourself'),
      content: Text(
        'The selected recipients include your own email address '
        '($ownEmail). Continue?',
      ),
      actions: [
        HMBButton(
          label: 'Cancel',
          hint: "Don't send this email",
          onPressed: () => Navigator.of(context).pop(false),
        ),
        HMBButton(
          label: 'Continue',
          hint: 'Continue sending this email',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
