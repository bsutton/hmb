import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../dao/_index.g.dart';
import '../../entity/invoice.dart';
import '../../util/format.dart';
import '../widgets/media/pdf_preview.dart';
import 'pdf/generate_invoice_pdf.dart';

class GenerateInvoicePdfButton extends StatelessWidget {
  const GenerateInvoicePdfButton({
    required this.context,
    required this.mounted,
    required this.invoice,
    super.key,
  });

  final BuildContext context;
  final bool mounted;
  final Invoice invoice;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: () async {
          var billBookingFee = true;
          var displayCosts = true;
          var displayGroupHeaders = true;
          var displayItems = true;
          var groupByTask = true; // Default to group by task

          final result = await showInvoiceOptionsDialog(context, displayCosts,
              displayGroupHeaders, displayItems, groupByTask, billBookingFee);

          if (result != null && mounted) {
            billBookingFee = result['billBookingFee'] ?? true;
            displayCosts = result['displayCosts'] ?? true;
            displayGroupHeaders = result['displayGroupHeaders'] ?? true;
            displayItems = result['displayItems'] ?? true;
            groupByTask = result['groupByTask'] ?? true;

            final filePath = await generateInvoicePdf(
              invoice,
              displayCosts: displayCosts,
              displayGroupHeaders: displayGroupHeaders,
              displayItems: displayItems,
            );
            final system = await DaoSystem().get();
            final job = await DaoJob().getById(invoice.jobId);
            final contact = await DaoContact().getPrimaryForJob(job!.id);
            final recipients = await DaoInvoice().getEmailsByInvoice(invoice);
            if (context.mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PdfPreviewScreen(
                      title:
                          '''Invoice #${invoice.bestNumber} ${job.summary}''',
                      filePath: filePath.path,
                      emailSubject:
                          '''${system!.businessName ?? 'Your'} Invoice #${invoice.bestNumber}''',
                      emailBody: '''
${contact!.firstName.trim()},
Please find the attached invoice for your job.

Due Date: ${formatLocalDate(invoice.dueDate, 'yyyy MMM dd')}
''',
                      emailRecipients: [
                        ...recipients,
                        if (Strings.isNotBlank(system.emailAddress))
                          system.emailAddress!
                      ],
                      onSent: () async => DaoInvoice().markSent(invoice)),
                ),
              );
            }
          }
        },
        child: const Text('Preview PDF'),
      );

  Future<Map<String, bool>?> showInvoiceOptionsDialog(
          BuildContext context,
          bool displayCosts,
          bool displayGroupHeaders,
          bool displayItems,
          bool groupByTask,
          bool billBookingFee) =>
      showDialog<Map<String, bool>>(
        context: context,
        builder: (context) {
          var tempDisplayCosts = displayCosts;
          var tempDisplayGroupHeaders = displayGroupHeaders;
          var tempDisplayItems = displayItems;
          final tempGroupByTask =
              groupByTask; // Temporary selection for grouping

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
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'displayCosts': tempDisplayCosts,
                      'displayGroupHeaders': tempDisplayGroupHeaders,
                      'displayItems': tempDisplayItems,
                      'groupByTask': tempGroupByTask,
                      'billBookingFee': billBookingFee
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
      );
}