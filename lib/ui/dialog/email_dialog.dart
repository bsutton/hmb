import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

import '../../entity/system.dart';
import '../../ui/widgets/hmb_toast.dart';
import '../widgets/hmb_button.dart';

class EmailDialog extends StatefulWidget {
  const EmailDialog({
    required this.subject,
    required this.body,
    required this.preferredRecipient,
    required this.emailRecipients,
    required this.system,
    required this.filePath,
    super.key,
  });

  final String subject;
  final String body;
  final String preferredRecipient;
  final List<String> emailRecipients;
  final System system;
  final String filePath;

  @override
  // ignore: library_private_types_in_public_api
  _EmailDialogState createState() => _EmailDialogState();
}

class _EmailDialogState extends State<EmailDialog> {
  late TextEditingController _subjectController;
  late TextEditingController _bodyController;
  String? _selectedRecipient;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.subject);
    _bodyController = TextEditingController(
      text:
          '''
${widget.body}

Regards,
${widget.system.businessName}
${widget.system.address}
Email: ${widget.system.emailAddress}
Phone: ${widget.system.bestPhone}
Web: ${widget.system.webUrl}
${widget.system.businessNumberLabel}: ${widget.system.businessNumber}
''',
    );
    _selectedRecipient = widget.preferredRecipient;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Send Email'),
    content: SingleChildScrollView(
      child: ListBody(
        children: <Widget>[
          DropdownButton<String>(
            value: _selectedRecipient,
            onChanged: (newValue) {
              setState(() {
                _selectedRecipient = newValue;
              });
            },
            items: widget.emailRecipients
                .map(
                  (recipient) => DropdownMenuItem<String>(
                    value: recipient,
                    child: Text(recipient),
                  ),
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
        onPressed: () {
          Navigator.of(context).pop(false);
        },
      ),
      HMBButton(
        label: 'Send...',
        onPressed: () async {
          if (!(Platform.isAndroid || Platform.isIOS)) {
            HMBToast.error('This platform does not support sending emails');
            return;
          }
          if (_selectedRecipient != null) {
            final email = Email(
              body: _bodyController.text,
              subject: _subjectController.text,
              recipients: [_selectedRecipient!],
              attachmentPaths: [widget.filePath],
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
  );
}
