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
import '../../entity/job.dart';
import '../../entity/system.dart';
import '../../ui/widgets/hmb_toast.dart';
import '../widgets/hmb_button.dart';
import '../widgets/select/hmb_select_email_multi.dart';

class EmailDialogForJob extends StatefulWidget {
  final Job job;
  final String subject;
  final String body;
  final String preferredRecipient;
  final List<String> attachmentPaths;

  const EmailDialogForJob({
    required this.job,
    required this.preferredRecipient,
    required this.subject,
    required this.body,
    required this.attachmentPaths,
    super.key,
  });

  @override
  // ignore: library_private_types_in_public_api
  _EmailDialogState createState() => _EmailDialogState();
}

class _EmailDialogState extends DeferredState<EmailDialogForJob> {
  late final System system;
  late TextEditingController _subjectController;
  late TextEditingController _bodyController;
  List<String> _selectedRecipients = [];

  @override
  Future<void> asyncInitState() async {
    system = await DaoSystem().get();

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
    _selectedRecipients = [widget.preferredRecipient];
  }

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.subject);
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (_) => AlertDialog(
      title: const Text('Send Email'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            HMBSelectEmailMulti(
              initialEmails: [widget.preferredRecipient],
              job: widget.job,
              onChanged: (selectedRecipients) {
                setState(() {
                  _selectedRecipients = selectedRecipients;
                });
              },
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
            if (_selectedRecipients.isNotEmpty) {
              final email = Email(
                body: _bodyController.text,
                subject: _subjectController.text,
                recipients: _selectedRecipients,
                attachmentPaths: widget.attachmentPaths,
              );

              if (!(Platform.isAndroid || Platform.isIOS)) {
                HMBToast.error('This platform does not support sending emails');
                return;
              }
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
}
