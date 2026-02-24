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

// lib/src/ui/assignment/build_send_assignment_button.dart

import 'package:flutter/material.dart';

import '../../../api/external_accounting.dart';
import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../dialog/email_dialog.dart';
import '../../widgets/media/pdf_preview.dart';
import '../../widgets/widgets.g.dart';
import 'generate_work_assignment_pdf.dart';

class BuildSendAssignmentButton extends StatelessWidget {
  final BuildContext context;
  final bool mounted;
  final WorkAssignment assignment;

  const BuildSendAssignmentButton({
    required this.context,
    required this.mounted,
    required this.assignment,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final sent = assignment.status;
    final buttonLabel = switch (sent) {
      WorkAssignmentStatus.unsent => 'Send Task Approval',
      WorkAssignmentStatus.sent => 'Send Task Approval (Sent)',
      WorkAssignmentStatus.modified => 'Send Task Approval (Modified)',
    };

    return HMBButtonSecondary(
      label: buttonLabel,
      hint: 'View and optionally send Task Approval to the customer',
      onPressed: () async {
        final job = await DaoJob().getById(assignment.jobId);
        if (job == null) {
          HMBToast.error('Job not found');
          return;
        }

        final primaryContact = await DaoContact().getById(assignment.contactId);
        if (primaryContact == null) {
          HMBToast.error('You must select a Contact');
          return;
        }

        final file = await BlockingUI().runAndWait(
          label: 'Generating Task Approval',
          () => generateWorkAssignmentPdf(assignment),
        );

        if (!context.mounted) {
          return;
        }

        final recipients = [primaryContact.emailAddress];

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PdfPreviewScreen(
              title: 'Task Approval #${assignment.id}',
              filePath: file.path,
              preferredRecipient: primaryContact.emailAddress,
              emailSubject: 'Task Approval #${assignment.id}',
              emailBody:
                  '''
${primaryContact.firstName},

Please find attached the Task Approval for Job ${job.summary}.
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
              onSent: () => DaoWorkAssignment().markSent(assignment),
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
