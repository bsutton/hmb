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

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../../dao/dao.g.dart';
import '../../entity/quote.dart';
import '../../entity/quote_line.dart';
import '../../util/dart/format.dart';
import '../crud/milestone/edit_milestone_payment.dart';
import '../dialog/email_dialog_for_job.dart';
import '../widgets/icons/hmb_edit_icon.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/media/pdf_preview.dart';
import '../widgets/text/hmb_text_themes.dart';
import '../widgets/widgets.g.dart' hide StatefulBuilder;
import 'edit_quote_line_dialog.dart';
import 'generate_quote_pdf.dart';
import 'quote_details.dart';
import 'select_billing_contact_dialog.dart';

class QuoteDetailsScreen extends StatefulWidget {
  final int quoteId;

  const QuoteDetailsScreen({required this.quoteId, super.key});

  @override
  _QuoteDetailsScreenState createState() => _QuoteDetailsScreenState();
}

class _QuoteDetailsScreenState extends DeferredState<QuoteDetailsScreen> {
  late var _quote = Quote.forInsert(
    jobId: 1,
    summary: '',
    description: '',
    totalAmount: Money.fromInt(0, isoCode: 'USD'),
  );

  @override
  Future<void> asyncInitState() async {
    _quote = await _loadQuote();
  }

  Future<Quote> _loadQuote() async {
    final quote = (await DaoQuote().getById(widget.quoteId))!;
    return quote;
  }

  Future<void> _refresh() async {
    _quote = await _loadQuote();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quote Details')),
    body: DeferredBuilder(
      this,
      builder: (context) => SingleChildScrollView(
        child: Surface(
          margin: const EdgeInsets.all(8),
          child: HMBColumn(
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
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quote #${_quote.id}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text('Issued: ${formatDate(_quote.createdDate)}'),
        Text('Job ID: ${_quote.jobId}'),
        HMBRow(
          children: [
            Text('State: ${_quote.state.name}'),
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
        HMBButton(
          label: 'Send...',
          hint: 'Send the quote by email',
          onPressed: () async =>
              _quote.state == QuoteState.rejected ||
                  _quote.state == QuoteState.withdrawn
              ? null
              : await _sendQuote(),
        ),
        HMBButton(
          label: 'Create Milestones',
          hint:
              '''Create payment milestones that are used to generate invoices for a Fixed Price Job''',
          onPressed: () async {
            if (!_quote.state.isPostApproval) {
              HMBToast.error(
                'You must approve the quote before creating milestones.',
              );
              return;
            }
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EditMilestonesScreen(quoteId: _quote.id),
              ),
            );
          },
        ),
        HMBButton(
          label: 'Create Invoice',
          hint: 'Create an Invoice for this quote - the entire amount',
          onPressed: _createInvoice,
        ),
      ],
    ),
  );

  Widget _buildQuoteLines() => FutureBuilderEx<QuoteDetails>(
    future: QuoteDetails.fromQuoteId(_quote.id, excludeHidden: false),
    debugLabel: 'QuoteDetailsScreen:_buildQuoteLines',
    builder: (context, jobQuote) {
      if (jobQuote == null || jobQuote.groups.isEmpty) {
        return const ListTile(title: Text('No quote lines found.'));
      }

      return HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: jobQuote.groups.map((groupWrap) {
          final group = groupWrap.group;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: HMBColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: HMBTextLine(
                        'Task: ${group.name} ${groupWrap.total}',
                      ),
                    ),
                  ],
                ),

                // Lines list
                Card(
                  child: HMBColumn(
                    children: groupWrap.lines
                        .map(
                          (line) => ListTile(
                            title: Text(line.description),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '''Qty: ${line.quantity} × ${line.unitCharge} = '''
                                  '${line.lineTotal}',
                                ),
                                Text(
                                  '''Status: ${line.lineChargeableStatus.description}''',
                                ),
                              ],
                            ),
                            trailing: HMBEditIcon(
                              onPressed: () async {
                                final editedLine = await showDialog<QuoteLine>(
                                  context: context,
                                  builder: (_) =>
                                      EditQuoteLineDialog(line: line),
                                );
                                if (editedLine != null) {
                                  await DaoQuoteLine().update(editedLine);
                                  await DaoQuote().recalculateTotal(
                                    editedLine.quoteId,
                                  );
                                  await _refresh();
                                }
                              },
                              hint: 'Edit Quote Line',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
          builder: (context, setState) => AlertDialog(
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
                hint: "Don't view the quote",
                onPressed: () => Navigator.of(context).pop(),
              ),
              HMBButton(
                label: 'OK',
                hint: 'View and optionally email this quote',
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
    final site = await DaoSite().getById(job.siteId);
    final address = site?.address;

    // final emailRecipients = await DaoQuote().getEmailsByQuote(_quote);

    final preferredRecipient =
        billingContact?.emailAddress; // ?? emailRecipients.firstOrNull;

    if (preferredRecipient == null) {
      HMBToast.error(
        'You must enter an email address for the preferred Contact',
      );
      return;
    }
    if (!mounted) {
      return;
    }
    // if (!emailRecipients.contains(preferredRecipient)) {
    //   emailRecipients.add(preferredRecipient);
    // }

    final businessPrefix = Strings.isBlank(system.businessName)
        ? ''
        : '${system.businessName}: ';

    final addressSuffix = address == null ? '' : ' for $address';
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PdfPreviewScreen(
          title: 'Quote #${_quote.id} ${job.summary}',
          filePath: filePath.path,
          emailSubject: '${businessPrefix}Your Quote$addressSuffix',
          emailBody: 'Please find the attached quote',
          preferredRecipient: preferredRecipient,
          sendEmailDialog:
              ({
                preferredRecipient = '',
                subject = '',
                body = '',
                attachmentPaths = const [],
              }) => EmailDialogForJob(
                job: job,
                preferredRecipient: preferredRecipient,
                subject: subject,
                body: body,
                attachmentPaths: attachmentPaths,
              ),
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
      if (!_quote.state.isPostApproval) {
        HMBToast.error(
          'You must approve the quote before creating an invoice.',
        );
        return;
      }
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
}
