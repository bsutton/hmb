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
import 'package:flutter_email_sender/flutter_email_sender.dart';

import '../widgets/blocking_ui.dart';
import '../widgets/hmb_button.dart';
import 'hmb_email_sender.dart';

enum EmailDeliveryOutcome { cancelled, sentDirectly, openedComposer }

enum _EmailDeliveryMethod { direct, composer }

/// Lets the user choose how an already-edited email should be delivered.
///
/// When SMTP is unavailable, this retains the existing behaviour and opens the
/// platform email composer immediately.
Future<EmailDeliveryOutcome> deliverEmail({
  required BuildContext context,
  required Email email,
}) async {
  final sender = HMBEmailSender();
  if (!await sender.canSendDirectly()) {
    await sender.openComposer(email);
    return EmailDeliveryOutcome.openedComposer;
  }
  if (!context.mounted) {
    return EmailDeliveryOutcome.cancelled;
  }

  final method = await showDialog<_EmailDeliveryMethod>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Send email'),
      content: const Text(
        'Send this email immediately from HMB, or open it in your email app '
        'for another review?',
      ),
      actions: [
        HMBButton(
          label: 'Cancel',
          hint: "Don't send this email",
          onPressed: () => Navigator.of(context).pop(),
        ),
        HMBButton(
          label: 'Open email app',
          hint: 'Review and send this email using your device email app',
          onPressed: () =>
              Navigator.of(context).pop(_EmailDeliveryMethod.composer),
        ),
        HMBButton(
          label: 'Send now',
          hint: 'Send this email immediately using configured SMTP',
          onPressed: () =>
              Navigator.of(context).pop(_EmailDeliveryMethod.direct),
        ),
      ],
    ),
  );

  switch (method) {
    case _EmailDeliveryMethod.direct:
      await BlockingUI().runAndWait(
        () => sender.sendDirectly(email),
        label: 'Sending email',
      );
      return EmailDeliveryOutcome.sentDirectly;
    case _EmailDeliveryMethod.composer:
      await sender.openComposer(email);
      return EmailDeliveryOutcome.openedComposer;
    case null:
      return EmailDeliveryOutcome.cancelled;
  }
}

String emailDeliveryMessage(EmailDeliveryOutcome outcome) => switch (outcome) {
  EmailDeliveryOutcome.sentDirectly => 'Email sent successfully',
  EmailDeliveryOutcome.openedComposer => 'Email opened in your email app',
  EmailDeliveryOutcome.cancelled => '',
};
