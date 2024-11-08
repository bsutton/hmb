import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dao/dao_system.dart';
import '../dialog/email_dialog.dart';
import 'hmb_toast.dart';

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({
    required this.title,
    required this.emailSubject,
    required this.emailBody,
    required this.filePath,
    required this.emailRecipients,
    required this.onSent,
    super.key,
  });
  final String title;
  final String filePath;

  final String emailSubject;
  final String emailBody;
  final List<String> emailRecipients;
  final Future<void> Function() onSent;

  Future<void> _showEmailDialog(BuildContext context) async {
    final system = await DaoSystem().get();

    if (emailRecipients.isEmpty) {
      HMBToast.error('No contacts have an email address');
      return;
    }

    if (context.mounted) {
      final sent = await showDialog<bool>(
        context: context,
        builder: (context) => EmailDialog(
          emailRecipients: emailRecipients,
          system: system!,
          filePath: filePath,
          subject: emailSubject,
          body: emailBody,
        ),
      );
      if (sent ?? false) {
        await onSent();
      }
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
                child: PdfViewer.file(
                  filePath,
                  params: PdfViewerParams(
                    linkHandlerParams: PdfLinkHandlerParams(
                      onLinkTap: (link) async {
                        // handle URL or Dest
                        if (link.url != null) {
                          await launchUrl(link.url!);
                        }
                        // else if (link.dest != null) {
                        //   controller.goToDest(link.dest);
                        // }
                      },
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      );
}
