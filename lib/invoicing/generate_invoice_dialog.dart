import 'package:flutter/material.dart';

import '../entity/invoice.dart';
import '../widgets/pdf_preview.dart';
import 'list_invoice_screen.dart';
import 'pdf/generate_invoice_pdf.dart';

class GenerateInvoiceDialog extends StatelessWidget {
  const GenerateInvoiceDialog({
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
              var tempGroupByTask =
                  groupByTask; // Temporary selection for grouping

              return StatefulBuilder(
                builder: (context, setState) => AlertDialog(
                  title: const Text('Select Invoice Options'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<bool>(
                        value: tempGroupByTask,
                        items: const [
                          DropdownMenuItem(
                            value: true,
                            child: Text('Group by Task/Date'),
                          ),
                          DropdownMenuItem(
                            value: false,
                            child: Text('Group by Date/Task'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            tempGroupByTask = value ?? true;
                          });
                        },
                        isExpanded: true,
                      ),
                      const SizedBox(height: 20),
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

            if (context.mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PdfPreviewScreen(
                    title:
                        '''Invoice #${invoice.bestNumber} ${widget.job.summary}''',
                    filePath: filePath.path,
                    emailRecipients: const [],
                  ),
                ),
              );
            }
          }
        },
        child: const Text('Generate and Preview PDF'),
      );
}
