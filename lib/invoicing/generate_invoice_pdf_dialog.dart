import 'package:flutter/material.dart';

import '../dao/_index.g.dart';
import '../entity/invoice.dart';
import '../util/format.dart';
import '../widgets/pdf_preview.dart';
import 'list_invoice_screen.dart';
import 'pdf/generate_invoice_pdf.dart';

class GenerateInvoicePdfDialog extends StatelessWidget {
  const GenerateInvoicePdfDialog({
    required this.context,
    required this.mounted,
    required this.widget,
    required this.invoice,
    super.key,
  });

  final BuildContext context;
  final bool mounted;
  final InvoiceListScreen widget;
  final Invoice invoice;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: () async {
          var billBookingFee = true;
          var displayCosts = true;
          var displayGroupHeaders = true;
          var displayItems = true;
          var groupByTask = true; // Default to group by task

          final result = await showDialog<Map<String, bool>>(
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
            final contact = await DaoContact().getForJob(job!.id);
            final recipients = await DaoInvoice().getEmailsByInvoice(invoice);
            if (context.mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PdfPreviewScreen(
                    title:
                        '''Invoice #${invoice.bestNumber} ${widget.job.summary}''',
                    filePath: filePath.path,
                    emailSubject:
                        '''${system!.businessName ?? 'Your'} Invoice #${invoice.bestNumber}''',
                    emailBody: '''
${contact!.firstName},
Please find the attached invoice for your job.

Due Date: ${formatLocalDate(invoice.dueDate, 'yyyy MMM dd')}
''',
                    emailRecipients: [
                      ...recipients,
                      if (system.emailAddress != null) system.emailAddress!
                    ],
                  ),
                ),
              );
            }
          }
        },
        child: const Text('Generate and Preview PDF'),
      );
}
