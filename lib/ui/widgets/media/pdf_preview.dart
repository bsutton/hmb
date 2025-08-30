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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:zoom_view/zoom_view.dart';

import '../../../dao/dao_system.dart';
import '../../../ui/widgets/hmb_toast.dart';
import '../../../util/types.dart';
import '../../dialog/email_dialog.dart';
import '../blocking_ui.dart';
import '../desktop_back_gesture_suppress.dart';

class EmailBlocked {
  String reason;
  bool blocked;

  EmailBlocked({required this.blocked, required this.reason});
}

class PdfPreviewScreen extends StatelessWidget {
  final pdfViewerController = PdfViewerController();
  final controller = ScrollController();
  final String title;
  final String filePath;
  final String emailSubject;
  final String emailBody;
  final String preferredRecipient;
  final List<String> emailRecipients;
  final AsyncVoidCallback onSent;
  final Future<EmailBlocked> Function() canEmail;

  PdfPreviewScreen({
    required this.title,
    required this.emailSubject,
    required this.emailBody,
    required this.filePath,
    required this.preferredRecipient,
    required this.emailRecipients,
    required this.canEmail,
    required this.onSent,
    super.key,
  });

  Future<void> _showEmailDialog(BuildContext context) async {
    final system = await DaoSystem().get();

    final emailBlocked = await canEmail();
    if (emailBlocked.blocked) {
      HMBToast.error(
        'You can not email this document as ${emailBlocked.reason}',
      );
      return;
    }

    if (emailRecipients.isEmpty) {
      HMBToast.error('No contacts have an email address');
      return;
    }

    if (context.mounted) {
      final sent = await showDialog<bool>(
        context: context,
        builder: (context) => EmailDialog(
          preferredRecipient: preferredRecipient,
          emailRecipients: emailRecipients,
          system: system,
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
          onPressed: () => unawaited(_showEmailDialog(context)),
        ),
      ],
    ),
    body: Center(
      child: Column(
        children: [
          Expanded(
            child: BlockingUITransition<Widget>(
              label: 'Rendering PDF',
              slowAction: () async {
                final pages = await _loadPages(context);

                return DesktopBackGestureSuppress(
                  child: ZoomListView(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      controller: controller,
                      itemCount: pages.length,
                      itemBuilder: (context, index) => pages[index],
                    ),
                  ),
                );
              },

              builder: (context, widget) => widget!,
            ),
          ),
        ],
      ),
    ),
  );

  Future<List<Widget>> _loadPages(BuildContext context) async {
    final doc = await PdfDocument.openFile(filePath);
    final pageWidgets = <Widget>[];

    for (var i = 0; i < doc.pages.length; i++) {
      final widget = PdfPageView(
        document: doc,
        pageNumber: i + 1, // base 1

        pageSizeCallback: (biggestSize, page) => Size(page.width, page.height),
      );

      pageWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: widget,
        ),
      );
    }

    return pageWidgets;
  }
}
