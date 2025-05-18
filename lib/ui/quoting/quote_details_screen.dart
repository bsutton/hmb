import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao.g.dart';
import '../../entity/quote.dart';
import '../../entity/quote_line.dart';
import '../../util/format.dart';
import '../crud/milestone/edit_milestone_payment.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/media/pdf_preview.dart';
import '../widgets/surface.dart';
import 'edit_quote_line_dialog.dart';
import 'generate_quote_pdf.dart';
import 'job_quote.dart';
import 'select_billing_contact_dialog.dart';

class QuoteDetailsScreen extends StatefulWidget {
  const QuoteDetailsScreen({required this.quoteId, super.key});
  final int quoteId;

  @override
  _QuoteDetailsScreenState createState() => _QuoteDetailsScreenState();
}

class _QuoteDetailsScreenState extends DeferredState<QuoteDetailsScreen> {
  late Quote _quote;

  @override
  Future<void> asyncInitState() async {
    _quote = await _loadQuote();
  }

  Future<Quote> _loadQuote() async =>
      (await DaoQuote().getById(widget.quoteId))!;

  Future<void> _refresh() async {
    _quote = await _loadQuote();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quote Details')),
    body: DeferredBuilder(
      this,
      builder:
          (context) => SingleChildScrollView(
            child: Surface(
              margin: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const Divider(),
                  _buildActions(),
                  const Divider(),
                  _buildQuoteLines(),
                ],
              ),
            ),
          ),
    ),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quote #${_quote.id}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text('Issued: ${formatDate(_quote.createdDate)}'),
        Text('Job ID: ${_quote.jobId}'),
        Row(
          children: [
            Text('State: ${_quote.state.name}'),
            const SizedBox(width: 8),
            if (_quote.state == QuoteState.sent && _quote.dateSent != null)
              Text('Sent: ${formatDate(_quote.dateSent!)}'),
            if (_quote.state == QuoteState.approved &&
                _quote.dateApproved != null)
              Text('Approved: ${formatDate(_quote.dateApproved!)}'),
          ],
        ),
      ],
    ),
  );

  Widget _buildActions() => Padding(
    padding: const EdgeInsets.all(8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        HMBButton(label: 'Send...', onPressed: _sendQuote),
        HMBButton(
          label: 'Create Milestones',
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => EditMilestonesScreen(quoteId: _quote.id),
              ),
            );
          },
        ),
        HMBButton(label: 'Create Invoice', onPressed: _createInvoice),
      ],
    ),
  );

  Widget _buildQuoteLines() => FutureBuilderEx<JobQuote>(
    future: JobQuote.fromQuoteId(_quote.id),
    builder: (context, jobQuote) {
      if (jobQuote == null || jobQuote.groups.isEmpty) {
        return const ListTile(title: Text('No quote lines found.'));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            jobQuote.groups
                .map(
                  (group) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.group.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children:
                                group.lines
                                    .map(
                                      (line) => ListTile(
                                        title: Text(line.description),
                                        subtitle: Text(
                                          'Qty: ${line.quantity} × ${line.unitCharge} = ${line.lineTotal}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              onPressed: () async {
                                                final editedLine =
                                                    await showDialog<QuoteLine>(
                                                      context: context,
                                                      builder:
                                                          (context) =>
                                                              EditQuoteLineDialog(
                                                                line: line,
                                                              ),
                                                    );
                                                if (editedLine != null) {
                                                  await DaoQuoteLine().update(
                                                    editedLine,
                                                  );
                                                  await DaoQuote()
                                                      .recalculateTotal(
                                                        editedLine.quoteId,
                                                      );
                                                  await _refresh();
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.cancel),
                                              tooltip: 'Reject line item',
                                              onPressed:
                                                  () => _rejectQuoteLine(line),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      );
    },
  );

  Future<void> _sendQuote() async {
    var displayCosts = true;
    var displayGroupHeaders = true;
    var displayItems = true;

    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (context) {
        var tempDisplayCosts = displayCosts;
        var tempDisplayGroupHeaders = displayGroupHeaders;
        var tempDisplayItems = displayItems;

        return StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: const Text('Select Quote Options'),
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
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  HMBButton(
                    label: 'OK',
                    onPressed: () {
                      Navigator.of(context).pop({
                        'displayCosts': tempDisplayCosts,
                        'displayGroupHeaders': tempDisplayGroupHeaders,
                        'displayItems': tempDisplayItems,
                      });
                    },
                  ),
                ],
              ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    displayCosts = result['displayCosts'] ?? true;
    displayGroupHeaders = result['displayGroupHeaders'] ?? true;
    displayItems = result['displayItems'] ?? true;

    final filePath = await generateQuotePdf(
      _quote,
      displayCosts: displayCosts,
      displayGroupHeaders: displayGroupHeaders,
      displayItems: displayItems,
    );

    final system = await DaoSystem().get();
    final job = (await DaoJob().getById(_quote.jobId))!;
    final billingContact = await DaoContact().getBillingContactByJob(job);
    final contacts = await DaoContact().getByJob(_quote.jobId);
    final emailRecipients =
        contacts.map((contact) => contact.emailAddress).toList();

    final preferredRecipient =
        billingContact?.emailAddress ??
        (emailRecipients.isNotEmpty ? emailRecipients.first : null);

    if (preferredRecipient == null) {
      HMBToast.error(
        'You must entere an email address for the preferred Contact',
      );
      return;
    }
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (context) => PdfPreviewScreen(
              title: 'Quote #${_quote.id} ${job.summary}',
              filePath: filePath.path,
              emailSubject: '${system.businessName ?? 'Your'} Quote',
              emailBody: 'Please find the attached quote',
              preferredRecipient: preferredRecipient,
              emailRecipients: emailRecipients,
              onSent: () async {
                if (_quote.state != QuoteState.approved) {
                  await DaoQuote().markQuoteSent(_quote.id);
                  await _refresh();
                }
              },
              canEmail: () async => EmailBlocked(blocked: false, reason: ''),
            ),
      ),
    );
  }

  Future<void> _createInvoice() async {
    try {
      final customer = await DaoCustomer().getByQuote(_quote.id);
      final job = await DaoJob().getJobForQuote(_quote.id);
      final initialContact = await DaoContact().getBillingContactByJob(job);

      if (!mounted) {
        return;
      }

      final billingContact = await SelectBillingContactDialog.show(
        context,
        customer!,
        initialContact,
        (contact) {},
      );
      if (billingContact == null) {
        return;
      }

      final invoice = await createFixedPriceInvoice(_quote, billingContact);

      _quote.state = QuoteState.invoiced;
      await DaoQuote().update(_quote);
      HMBToast.info('Invoice #${invoice.id} created successfully.');
    } catch (e) {
      HMBToast.error('Failed to create invoice: $e');
    }
  }

  Future<void> _rejectQuoteLine(QuoteLine line) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        var alsoRejectTask = false;
        return AlertDialog(
          title: const Text('Reject Quote Line'),
          content: StatefulBuilder(
            builder:
                (context, setState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Do you want to reject this quote item?'),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text(
                        'Also mark the associated task as rejected',
                      ),
                      value: alsoRejectTask,
                      onChanged: (value) {
                        setState(() {
                          alsoRejectTask = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
          ),
          actions: [
            HMBButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context, false),
            ),
            HMBButton(
              label: 'Reject',
              onPressed: () => Navigator.pop(context, alsoRejectTask),
            ),
          ],
        );
      },
    );

    if (confirm == null) {
      return;
    }


    if (confirm) {
    await DaoQuoteLine().markRejected(line.id);
    }

    await DaoQuote().recalculateTotal(line.quoteId);
    await _refresh();
  }
}
