// lib/src/ui/assignment/build_send_assignment_button.dart

import 'package:flutter/material.dart';

import '../../../api/external_accounting.dart';
import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../widgets/media/media.g.dart';
import '../../widgets/widgets.g.dart';
import 'generate_assignment_pdf.dart';

class BuildSendAssignmentButton extends StatelessWidget {
  const BuildSendAssignmentButton({
    required this.context,
    required this.mounted,
    required this.assignment,
    super.key,
  });

  final BuildContext context;
  final bool mounted;
  final SupplierAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final sent = assignment.sent;
    final buttonLabel = sent ? 'View/Send... (Sent)' : 'View/Send...';

    return HMBButton(
      label: buttonLabel,
      onPressed: () async {
        final job = await DaoJob().getById(assignment.jobId);
        if (job == null) {
          HMBToast.error('Job not found');
          return;
        }

        final primaryContact = await DaoContact().getById(assignment.contactId);
        if (primaryContact == null) {
          HMBToast.error('You must select a Supplier Contact');
          return;
        }

        final file = await BlockingUI().runAndWait(
          label: 'Generating Assignment',
          () => generateAssignmentPdf(assignment),
        );

        final systemEmail = (await DaoSystem().get()).emailAddress;
        if (!context.mounted) {
          return;
        }

        final recipients = [primaryContact.emailAddress, ?systemEmail];

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PdfPreviewScreen(
              title: 'Assignment #${assignment.id}',
              filePath: file.path,
              preferredRecipient: recipients.first,
              emailSubject: 'Work Assignment #${assignment.id}',
              emailBody:
                  '''
${primaryContact.firstName},

Please find attached the work assignment for Job ${job.summary}.
''',
              emailRecipients: [...recipients],
              onSent: () => DaoSupplierAssignment().markSent(assignment),
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
