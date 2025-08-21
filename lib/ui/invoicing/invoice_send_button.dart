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
import 'package:strings/strings.dart';

import '../../api/external_accounting.dart';
import '../../dao/dao.g.dart';
import '../../entity/invoice.dart';
import '../../util/format.dart';
import '../widgets/blocking_ui.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/media/pdf_preview.dart';
import 'pdf/generate_invoice_pdf.dart';

class BuildSendButton extends StatelessWidget {
  final BuildContext context;
  final bool mounted;
  final Invoice invoice;

  const BuildSendButton({
    required this.context,
    required this.mounted,
    required this.invoice,
    super.key,
  });


  @override
  Widget build(BuildContext context) => HMBButton(
    label: 'View/Send...',
    hint: 'View and optionally email the Invoice',
    onPressed: () async {
      var billBookingFee = true;
      var displayCosts = true;
      var displayGroupHeaders = true;
      var displayItems = true;
      var groupByTask = true; // Default to group by task

      final job = await DaoJob().getById(invoice.jobId);
      final primaryContact = await DaoContact().getPrimaryForJob(job!.id);
      if (primaryContact == null) {
        HMBToast.error('You must first set a Contact on the Job');
        return;
      }

      final billingContact = await DaoContact().getBillingContactByJob(job);

      if (!context.mounted) {
        return;
      }
      final result = await showInvoiceOptionsDialog(
        context: context,
        displayCosts: displayCosts,
        displayGroupHeaders: displayGroupHeaders,
        displayItems: displayItems,
        groupByTask: groupByTask,
        billBookingFee: billBookingFee,
      );

      if (result != null && mounted) {
        billBookingFee = result['billBookingFee'] ?? true;
        displayCosts = result['displayCosts'] ?? true;
        displayGroupHeaders = result['displayGroupHeaders'] ?? true;
        displayItems = result['displayItems'] ?? true;
        groupByTask = result['groupByTask'] ?? true;

        final filePath = await BlockingUI().runAndWait(
          label: 'Generating Invoice',
          () => generateInvoicePdf(
            invoice,
            displayCosts: displayCosts,
            displayGroupHeaders: displayGroupHeaders,
            displayItems: displayItems,
          ),
        );
        final system = await DaoSystem().get();

        final recipients = await DaoInvoice().getEmailsByInvoice(invoice);
        if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => PdfPreviewScreen(
                title: '''Invoice #${invoice.bestNumber} ${job.summary}''',
                filePath: filePath.path,
                preferredRecipient:
                    billingContact?.emailAddress ?? recipients.first,
                emailSubject:
                    '''${system.businessName ?? 'Your'} Invoice #${invoice.bestNumber}''',
                emailBody:
                    '''
${primaryContact.firstName.trim()},
Please find the attached invoice for your job.

Due Date: ${formatLocalDate(invoice.dueDate, 'yyyy MMM dd')}
''',
                emailRecipients: [
                  ...recipients,
                  if (Strings.isNotBlank(system.emailAddress))
                    system.emailAddress!,
                ],
                onSent: () => DaoInvoice().markSent(invoice),
                canEmail: () async {
                  if ((await ExternalAccounting().isEnabled()) &&
                      !invoice.isUploaded()) {
                    return EmailBlocked(
                      blocked: true,
                      reason: 'the invoice has not been uploaded.',
                    );
                  } else {
                    return EmailBlocked(blocked: false, reason: '');
                  }
                },
              ),
            ),
          );
        }
      }
    },
  );

  Future<Map<String, bool>?> showInvoiceOptionsDialog({
    required BuildContext context,
    required bool displayCosts,
    required bool displayGroupHeaders,
    required bool displayItems,
    required bool groupByTask,
    required bool billBookingFee,
  }) => showDialog<Map<String, bool>>(
    context: context,
    builder: (context) {
      var tempDisplayCosts = displayCosts;
      var tempDisplayGroupHeaders = displayGroupHeaders;
      var tempDisplayItems = displayItems;
      final tempGroupByTask = groupByTask; // Temporary selection for grouping

      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Invoice Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Display Costs'),
                value: tempDisplayCosts,
                onChanged: (value) {
                  setState(() {
                    tempDisplayCosts = value ?? true;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Display Group Headers'),
                value: tempDisplayGroupHeaders,
                onChanged: (value) {
                  setState(() {
                    tempDisplayGroupHeaders = value ?? true;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Display Items'),
                value: tempDisplayItems,
                onChanged: (value) {
                  setState(() {
                    tempDisplayItems = value ?? true;
                  });
                },
              ),
            ],
          ),
          actions: [
            HMBButton(
              onPressed: () => Navigator.of(context).pop(),
              label: 'Cancel',
              hint: "Don't send the invoice",
            ),
            HMBButton(
              hint: 'View and optionally send the invoice',
              onPressed: () {
                Navigator.of(context).pop({
                  'displayCosts': tempDisplayCosts,
                  'displayGroupHeaders': tempDisplayGroupHeaders,
                  'displayItems': tempDisplayItems,
                  'groupByTask': tempGroupByTask,
                  'billBookingFee': billBookingFee,
                });
              },
              label: 'OK',
            ),
          ],
        ),
      );
    },
  );
}
