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

import '../../../api/external_accounting.dart';
import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../dialog/email_dialog.dart';
import '../../widgets/media/pdf_preview.dart';
import '../../widgets/widgets.g.dart';
import 'generate_task_approval_pdf.dart';

class BuildSendTaskApprovalButton extends StatelessWidget {
  final BuildContext context;
  final bool mounted;
  final TaskApproval approval;

  const BuildSendTaskApprovalButton({
    required this.context,
    required this.mounted,
    required this.approval,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final sent = approval.status;
    final buttonLabel = switch (sent) {
      TaskApprovalStatus.unsent => 'View/Send...',
      TaskApprovalStatus.sent => 'View/Send... (Sent)',
      TaskApprovalStatus.modified => 'View/Send... (Modified)',
    };

    return HMBButtonSecondary(
      label: buttonLabel,
      hint: 'View and optionally send the Task Approval to the customer',
      onPressed: () async {
        final job = await DaoJob().getById(approval.jobId);
        if (job == null) {
          HMBToast.error('Job not found');
          return;
        }

        final contact = await DaoContact().getById(approval.contactId);
        if (contact == null) {
          HMBToast.error('You must select a Customer Contact');
          return;
        }

        final file = await BlockingUI().runAndWait(
          label: 'Generating Task Approval',
          () => generateTaskApprovalPdf(approval),
        );

        if (!context.mounted) {
          return;
        }

        final recipients = [contact.emailAddress];

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PdfPreviewScreen(
              title: 'Task Approval #${approval.id}',
              filePath: file.path,
              preferredRecipient: contact.emailAddress,
              emailSubject: 'Task Approval #${approval.id}',
              emailBody:
                  '''
${contact.firstName},

Please find attached the task list for your approval for Job ${job.summary}.
''',
              sendEmailDialog:
                  ({
                    preferredRecipient = '',
                    subject = '',
                    body = '',
                    attachmentPaths = const [],
                  }) => EmailDialog(
                    preferredRecipient: preferredRecipient,
                    subject: subject,
                    body: body,
                    attachmentPaths: attachmentPaths,
                    emailRecipients: [...recipients],
                  ),
              onSent: () => DaoTaskApproval().markSent(approval),
              canEmail: () async {
                if (await ExternalAccounting().isEnabled()) {
                  return EmailBlocked(blocked: false, reason: '');
                }
                return EmailBlocked(blocked: false, reason: '');
              },
            ),
          ),
        );
      },
    );
  }
}
