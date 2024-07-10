import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../dao/dao_system.dart';
import '../dialog/email_dialog.dart';
import 'hmb_toast.dart';

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({
    required this.title,
    required this.filePath,
    required this.emailRecipients,
    super.key,
  });
  final String title;
  final String filePath;
  final List<String> emailRecipients;

  Future<void> _showEmailDialog(BuildContext context) async {
    final system = await DaoSystem().get();

    if (emailRecipients.isEmpty) {
      HMBToast.error('No contacts have an email address');
      return;
    }

    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => EmailDialog(
          emailRecipients: emailRecipients,
          system: system!,
          filePath: filePath,
          subject: 'Invanhoe Handyman quote',
          body: 'Please find the attached Quotation',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: const Icon(Icons.email),
              onPressed: () async => _showEmailDialog(context),
            ),
          ],
        ),
        body: Center(
          child: Column(
            children: [
              Expanded(
                child: PdfViewer.file(filePath),
              ),
            ],
          ),
        ),
      );
}
