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

import 'dart:io';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_system.dart';
import '../../entity/system.dart';
import '../../ui/widgets/hmb_toast.dart';
import '../widgets/hmb_button.dart';
import '../widgets/select/hmb_droplist.dart';

class EmailDialog extends StatefulWidget {
  final String subject;
  final String body;
  final String preferredRecipient;
  final List<String> emailRecipients;
  final List<String> attachmentPaths;

  const EmailDialog({
    required this.subject,
    required this.body,
    required this.preferredRecipient,
    required this.emailRecipients,
    required this.attachmentPaths,
    super.key,
  });

  @override
  // ignore: library_private_types_in_public_api
  _EmailDialogState createState() => _EmailDialogState();
}

class _EmailDialogState extends DeferredState<EmailDialog> {
  late final System system;
  late TextEditingController _subjectController;
  late TextEditingController _bodyController;
  String? _selectedRecipient;
  late final List<String> emailRecipients;

  @override
  void initState() {
    super.initState();

    emailRecipients = [...widget.emailRecipients];
    _subjectController = TextEditingController(text: widget.subject);
  }

  @override
  Future<void> asyncInitState() async {
    system = await DaoSystem().get();

    if (Strings.isNotBlank(system.emailAddress)) {
      emailRecipients.add(system.emailAddress!);
    }

    final businessDetails = StringBuffer();
    if (Strings.isNotBlank(system.businessNumber)) {
      businessDetails
        ..write(
          Strings.orElseOnBlank(system.businessNumberLabel, 'Business No.'),
        )
        ..write(system.businessNumber);
    }
    _bodyController = TextEditingController(
      text:
          '''
${widget.body}

Regards,
${system.businessName}
${system.address}
Email: ${system.emailAddress}
Phone: ${system.bestPhone}
Web: ${system.webUrl}
$businessDetails
''',
    );
    _selectedRecipient = widget.preferredRecipient;
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => AlertDialog(
      title: const Text('Send Email'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            HMBDroplist<String>(
              title: 'Recepients',
              selectedItem: () async => _selectedRecipient,
              onChanged: (newValue) {
                setState(() {
                  _selectedRecipient = newValue;
                });
              },
              format: (emailAddress) => emailAddress,
              items: (filter) async => emailRecipients
                  .where(
                    (email) =>
                        Strings.isBlank(filter) || email.contains(filter!),
                  )
                  .toList(),
            ),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(labelText: 'Body'),
              maxLines: 5,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        HMBButton(
          label: 'Cancel',
          hint: "Don't send the email",
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
        HMBButton(
          label: 'Send...',
          hint:
              '''Send the email using your devices email app. You will have another opportunity to cancel the send.''',
          onPressed: () async {
            if (!(Platform.isAndroid || Platform.isIOS)) {
              HMBToast.error('This platform does not support sending emails');
              return;
            }
            if (_selectedRecipient != null) {
              if (!await _confirmSendingToSelf([_selectedRecipient!])) {
                return;
              }
              final email = Email(
                body: _bodyController.text,
                subject: _subjectController.text,
                recipients: [_selectedRecipient!],
                attachmentPaths: widget.attachmentPaths,
              );

              await FlutterEmailSender.send(email);
              HMBToast.info('Email sent successfully');
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            } else {
              HMBToast.info('Please select a recipient');
            }
          },
        ),
      ],
    ),
  );

  Future<bool> _confirmSendingToSelf(List<String> recipients) async {
    final systemEmail = system.emailAddress?.trim().toLowerCase();
    if (Strings.isBlank(systemEmail)) {
      return true;
    }
    final sendingToSelf = recipients
        .map((email) => email.trim().toLowerCase())
        .contains(systemEmail);
    if (!sendingToSelf) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sending to yourself'),
        content: Text(
          'The selected recipient is your own email address '
          '(${system.emailAddress}). Continue?',
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
}
