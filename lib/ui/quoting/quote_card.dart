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

// quote_list_screen.dart

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart' hide StatefulBuilder;
import 'package:strings/strings.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/format.dart';
import '../../util/dart/types.dart';
import '../crud/job/full_page_list_job_card.dart';
import '../crud/milestone/edit_milestone_payment.dart';
import '../dialog/email_dialog_for_job.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/media/pdf_preview.dart';
import '../widgets/widgets.g.dart';
import 'generate_quote_pdf.dart';
import 'job_and_customer.dart';

enum _RejectAction { quoteOnly, quoteAndJob }

class QuoteCard extends StatefulWidget {
  final Quote quote;
  final ValueChanged<Quote> onStateChanged;

  const QuoteCard({
    required this.quote,
    required this.onStateChanged,
    super.key,
  });

  @override
  _QuoteCardState createState() => _QuoteCardState();
}

class _QuoteCardState extends DeferredState<QuoteCard> {
  late Quote quote;
  late JobAndCustomer jc;

  @override
  Future<void> asyncInitState() async {
    quote = widget.quote;
    jc = await JobAndCustomer.fromQuote(quote);
  }

  Future<void> _updateQuote(AsyncVoidCallback action) async {
    try {
      await action();
      quote = (await DaoQuote().getById(quote.id))!;
      HMBToast.info('Quote #${quote.id} updated.');
      // Notify the parent to remove this quote.
      widget.onStateChanged(quote);
    } catch (e) {
      HMBToast.error('Failed to update quote: $e');
    }
  }

  Future<void> _openMilestones() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditMilestonesScreen(quoteId: quote.id),
      ),
    );
    quote = (await DaoQuote().getById(quote.id))!;
    widget.onStateChanged(quote);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openInvoiceAction() async {
    if (!quote.state.isPostApproval) {
      HMBToast.info(
        'Approve the quote first, then create invoices via Milestones.',
      );
      return;
    }
    await _openMilestones();
  }

  Future<void> _viewSendQuote() async {
    final job = await DaoJob().getById(quote.jobId);
    if (job == null) {
      HMBToast.error('Unable to load the quote job.');
      return;
    }

    final primaryContact = await DaoContact().getPrimaryForQuote(quote.id);
    if (primaryContact == null) {
      HMBToast.error('You must first set a Contact on the Job');
      return;
    }

    var displayCosts = true;
    var displayGroupHeaders = true;
    var displayItems = true;

    if (!mounted) {
      return;
    }
    final result = await _showQuoteOptionsDialog(
      context: context,
      displayCosts: displayCosts,
      displayGroupHeaders: displayGroupHeaders,
      displayItems: displayItems,
    );
    if (result == null || !mounted) {
      return;
    }
    displayCosts = result['displayCosts'] ?? true;
    displayGroupHeaders = result['displayGroupHeaders'] ?? true;
    displayItems = result['displayItems'] ?? true;

    final quoteFile = await BlockingUI().runAndWait(
      label: 'Generating Quote',
      () => generateQuotePdf(
        quote,
        displayCosts: displayCosts,
        displayGroupHeaders: displayGroupHeaders,
        displayItems: displayItems,
      ),
    );

    final system = await DaoSystem().get();
    final billingContact = await DaoContact().getBillingContactByJob(job);
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PdfPreviewScreen(
          title: 'Quote #${quote.bestNumber} ${job.summary}',
          filePath: quoteFile.path,
          preferredRecipient:
              billingContact?.emailAddress ?? primaryContact.emailAddress,
          emailSubject: '${system.businessName ?? 'Your'} Quote #'
              '${quote.bestNumber}',
          emailBody: '''
${primaryContact.firstName.trim()},
Please find the attached quote for your job.
''',
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
          onSent: () => DaoQuote().markQuoteSent(quote.id),
          canEmail: () async => EmailBlocked(blocked: false, reason: ''),
        ),
      ),
    );

    quote = (await DaoQuote().getById(quote.id))!;
    widget.onStateChanged(quote);
    if (mounted) {
      setState(() {});
    }
  }

  Future<Map<String, bool>?> _showQuoteOptionsDialog({
    required BuildContext context,
    required bool displayCosts,
    required bool displayGroupHeaders,
    required bool displayItems,
  }) => showDialog<Map<String, bool>>(
    context: context,
    builder: (context) {
      var tempDisplayCosts = displayCosts;
      var tempDisplayGroupHeaders = displayGroupHeaders;
      var tempDisplayItems = displayItems;

      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Quote Options'),
          content: HMBColumn(
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
              hint: "Don't view/send this quote",
              onPressed: () => Navigator.of(context).pop(),
            ),
            HMBButton(
              label: 'OK',
              hint: 'View and optionally send the quote',
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

  Future<_RejectAction?> _promptRejectAction(BuildContext context) =>
      showDialog<_RejectAction>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject Quote'),
          content: const Text('Do you want to reject the job as well?'),
          actions: [
            HMBButton(
              label: 'Cancel',
              hint: 'Keep the quote unchanged',
              onPressed: () => Navigator.pop(context),
            ),
            HMBButton(
              label: 'Quote Only',
              hint: 'Reject the quote but keep the job active',
              onPressed: () => Navigator.pop(context, _RejectAction.quoteOnly),
            ),
            HMBButton(
              label: 'Quote + Job',
              hint: 'Reject the quote and the job',
              onPressed: () =>
                  Navigator.pop(context, _RejectAction.quoteAndJob),
            ),
          ],
        ),
      );

  Future<bool?> _promptWithdraw(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Withdraw Quote'),
      content: const Text('Withdraw this quote?'),
      actions: [
        HMBButton(
          label: 'Cancel',
          hint: 'Keep the quote unchanged',
          onPressed: () => Navigator.pop(context, false),
        ),
        HMBButton(
          label: 'Withdraw',
          hint: 'Mark the quote as withdrawn',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isApproved = quote.state == QuoteState.approved;
    final isRejected = quote.state == QuoteState.rejected;
    final isWithdrawn = quote.state == QuoteState.withdrawn;
    final showSentRollback = quote.state == QuoteState.approved;
    final showWithdrawn = quote.state == QuoteState.sent;

    return DeferredBuilder(
      this,
      builder: (context) => HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // details.
          HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HMBLinkInternal(
                    label: 'Job: #${quote.jobId}',
                    navigateTo: () async {
                      final job = await DaoJob().getById(quote.jobId);
                      return FullPageListJobCard(job!);
                    },
                  ),
                  const HMBSpacer(width: true),
                  Text(jc.job.summary),
                ],
              ),
              Text('Customer: ${jc.customer.name}'),
              Text('Primary Contact: ${jc.primaryContact?.fullname ?? 'N/A'}'),
              Text('Billing Contact: ${jc.billingContact?.fullname ?? 'N/A'}'),
              Text('Total: ${quote.totalAmount}'),
            ],
          ),
          // Display current state and date info.
          HMBRow(
            children: [
              Text(quote.state.name.toCapitalised()),
              if (quote.state == QuoteState.sent && quote.dateSent != null)
                Text('Sent: ${formatDate(quote.dateSent!)}'),
              if (quote.state == QuoteState.approved &&
                  quote.dateApproved != null)
                Text(formatDate(quote.dateApproved!)),
            ],
          ),

          HMBRow(
            children: [
              HMBButton(
                label: 'Send...',
                hint: 'View and optionally send this quote',
                enabled: !isRejected && !isWithdrawn,
                onPressed: _viewSendQuote,
              ),
              HMBButton(
                label: 'Milestones',
                hint: 'Open milestones for this quote',
                enabled: !isRejected && !isWithdrawn,
                onPressed: _openMilestones,
              ),
              HMBButton(
                label: 'Invoice',
                hint: 'Create invoice(s) from quote milestones',
                enabled: !isRejected && !isWithdrawn,
                onPressed: _openInvoiceAction,
              ),
            ],
          ),

          // --- State Update Buttons ---
          HMBRow(
            children: [
              HMBButton(
                label: showSentRollback ? 'Unapprove' : 'Approve',
                hint: showSentRollback
                    ? 'Move approved quote back to sent'
                    : 'Mark the quote as approved by the customer',
                enabled: showSentRollback || (!isApproved && !isWithdrawn),
                onPressed: () async {
                  await _updateQuote(() async {
                    if (showSentRollback) {
                      await DaoQuote().markQuoteSent(quote.id);
                    } else {
                      await DaoQuote().approveQuote(quote.id);
                    }
                  });
                },
              ),
              HMBButton(
                label: 'Reject',
                hint: 'Mark the quote as rejected by the Customer',
                // disable when already rejected
                enabled: !isRejected && !isWithdrawn,
                onPressed: () async {
                  final action = await _promptRejectAction(context);
                  if (action == null) {
                    return;
                  }

                  await _updateQuote(() async {
                    await DaoQuote().rejectQuote(quote.id);

                    if (action == _RejectAction.quoteAndJob) {
                      final job = await DaoJob().getById(quote.jobId);
                      if (job != null) {
                        job.status = JobStatus.rejected;
                        await DaoJob().update(job);
                      }
                    }
                  });
                },
              ),
              if (showWithdrawn)
                HMBButton(
                  label: 'Withdraw',
                  hint: 'Mark the quote as withdrawn by your business',
                  onPressed: () async {
                    final confirm = await _promptWithdraw(context);
                    if (confirm != true) {
                      return;
                    }
                    await _updateQuote(() async {
                      await DaoQuote().withdrawQuote(quote.id);
                    });
                  },
                ),
            ],
          ),
          // --- End State Buttons ---
        ],
      ),
    );
  }
}
