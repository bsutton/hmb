// quote_list_screen.dart
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/util.g.dart';
import '../crud/job/job.g.dart';
import '../invoicing/dialog_select_tasks.dart';
import '../invoicing/select_job_dialog.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_link_internal.dart';
import '../widgets/hmb_search.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/layout/hmb_spacer.dart';
import 'quote_details_screen.dart';

class QuoteListScreen extends StatefulWidget {
  const QuoteListScreen({super.key});

  @override
  _QuoteListScreenState createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends DeferredState<QuoteListScreen> {
  late List<Quote> _quotes;

  Job? selectedJob;
  Customer? selectedCustomer;
  String? filterText;
  // When false (the default) we do not display approved/rejected quotes.
  bool includeApprovedRejected = false;

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Quotes');
    await _refreshQuoteList();
  }

  Future<void> _refreshQuoteList() async {
    _quotes = await _fetchFilteredQuotes();
    setState(() {});
  }

  Future<List<Quote>> _fetchFilteredQuotes() async {
    // Get quotes by filter text from the DAO.
    var quotes = await DaoQuote().getByFilter(filterText);
    // Filter by selected job if one is chosen.
    if (selectedJob != null) {
      quotes = quotes.where((q) => q.jobId == selectedJob!.id).toList();
    }
    // Filter by selected customer if one is chosen.
    if (selectedCustomer != null) {
      quotes = await Future.wait(
        quotes.map((q) async {
          final job = await DaoJob().getById(q.jobId);
          return job?.customerId == selectedCustomer!.id ? q : null;
        }),
      ).then((list) => list.whereType<Quote>().toList());
    }
    // By default, exclude quotes whose state is approved or rejected.
    if (!includeApprovedRejected) {
      quotes = quotes
          .where((q) =>
              (q.state != QuoteState.approved) &&
              (q.state != QuoteState.rejected))
          .toList();
    }
    return quotes;
  }

  Future<void> _createQuote() async {
    final job = await SelectJobDialog.show(context);
    if (job == null) {
      return;
    }
    if (mounted) {
      final quoteOptions = await showQuote(context: context, job: job);
      if (quoteOptions != null) {
        try {
          if (!quoteOptions.billBookingFee &&
              quoteOptions.selectedTaskIds.isEmpty) {
            HMBToast.error('You must select a task or the booking fee',
                acknowledgmentRequired: true);
            return;
          }
          await DaoQuote().create(job, quoteOptions);
        } catch (e) {
          HMBToast.error('Failed to create quote: $e',
              acknowledgmentRequired: true);
        }
        await _refreshQuoteList();
      }
    }
  }

  Future<void> _deleteQuote(Quote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quote'),
        content: const Text('Are you sure you want to delete this quote?'),
        actions: [
          HMBButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          HMBButton(
            label: 'Delete',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      try {
        await DaoQuote().delete(quote.id);
        HMBToast.info('Quote deleted successfully.');
        await _refreshQuoteList();
      } catch (e) {
        HMBToast.error('Failed to delete quote: $e');
      }
    }
  }

  Future<void> _onFilterChanged(String value) async {
    filterText = value;
    await _refreshQuoteList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 80,
          title: HMBSearchWithAdd(
            onSearch: (filter) async => _onFilterChanged(filter ?? ''),
            onAdd: _createQuote,
          ),
        ),
        body: DeferredBuilder(this,
            builder: (context) => Column(
                  children: [
                    // --- FILTER SECTION ---
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          // A simple text filter.
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Filter Quotes',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) async {
                                await _onFilterChanged(value);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Switch to include approved/rejected quotes.
                          Row(
                            children: [
                              const Text('Include Approved/Rejected'),
                              Switch(
                                value: includeApprovedRejected,
                                onChanged: (val) async {
                                  includeApprovedRejected = val;
                                  await _refreshQuoteList();
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    // --- END FILTER SECTION ---
                    Expanded(
                      child: (_quotes.isEmpty)
                          ? const Center(child: Text('No quotes found.'))
                          : ListView.builder(
                              itemCount: _quotes.length,
                              itemBuilder: (context, index) {
                                final quote = _quotes[index];
                                return GestureDetector(
                                  onTap: () async {
                                    // Navigate to the details screen.
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (context) =>
                                            QuoteDetailsScreen(
                                                quoteId: quote.id),
                                      ),
                                    );
                                    await _refreshQuoteList();
                                  },
                                  child: QuoteSummaryCard(
                                    key: ValueKey(quote.hashCode),
                                    quote: quote,
                                    onDelete: () async => _deleteQuote(quote),
                                    onStateChanged: _refreshQuoteList,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                )),
      );
}

/// A summary card used in the list screen.
class QuoteSummaryCard extends StatefulWidget {
  const QuoteSummaryCard({
    required this.quote,
    required this.onDelete,
    required this.onStateChanged,
    super.key,
  });
  final Quote quote;
  final VoidCallback onDelete;
  final VoidCallback onStateChanged;

  @override
  _QuoteSummaryCardState createState() => _QuoteSummaryCardState();
}

class _QuoteSummaryCardState extends DeferredState<QuoteSummaryCard> {
  late Quote quote;

  late JobAndCustomer jc;
  @override
  Future<void> asyncInitState() async {
    quote = widget.quote;
    jc = await JobAndCustomer.fromQuote(quote);
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DeferredBuilder(this,
              builder: (context) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with summary information and a delete icon.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Quote #${quote.id} - Issued: ${formatDate(quote.createdDate)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: widget.onDelete,
                          ),
                        ],
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              HMBLinkInternal(
                                label: 'Job: #${quote.jobId}',
                                navigateTo: () async {
                                  final job =
                                      await DaoJob().getById(quote.jobId);
                                  return JobEditScreen(job: job);
                                },
                              ),
                              const HMBSpacer(width: true),
                              Text(jc.job.summary),
                            ],
                          ),
                          Text('Customer: ${jc.customer.name}'),
                          Text('Contact: ${jc.contact?.fullname ?? 'N/A'}'),
                        ],
                      ),

                      // Display the current state and (if set) date information.
                      Row(
                        children: [
                          Text(quote.state.name.toCapitalised()),
                          const SizedBox(width: 8),
                          if (quote.state.name == 'sent' &&
                              quote.dateSent != null)
                            Text('Sent: ${formatDate(quote.dateSent!)}'),
                          if (quote.state.name == 'approved' &&
                              quote.dateApproved != null)
                            Text(formatDate(quote.dateApproved!)),
                        ],
                      ),
                      // --- State Update Buttons ---
                      Row(
                        children: [
                          HMBButton(
                            label: 'Approved',
                            onPressed: () async {
                              try {
                                await DaoQuote().approveQuote(quote.id);
                                HMBToast.info('Quote approved.');
                                quote = (await DaoQuote().getById(quote.id))!;
                                setState(() {});
                                widget.onStateChanged();
                              } catch (e) {
                                HMBToast.error('Failed to approve quote: $e');
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          HMBButton(
                            label: 'Rejected',
                            onPressed: () async {
                              try {
                                await DaoQuote().rejectQuote(quote.id);
                                HMBToast.info('Quote rejected.');
                                quote = (await DaoQuote().getById(quote.id))!;
                                setState(() {});
                                widget.onStateChanged();
                              } catch (e) {
                                HMBToast.error('Failed to reject quote: $e');
                              }
                            },
                          ),
                        ],
                      ),
                      // --- End State Buttons ---
                    ],
                  )),
        ),
      );
}

/// Helper class to load both Job and Customer details for a given Quote.
class JobAndCustomer {
  JobAndCustomer(
      {required this.job, required this.customer, required this.contact});
  final Job job;
  final Customer customer;
  final Contact? contact;
  static Future<JobAndCustomer> fromQuote(Quote quote) async {
    final job = await DaoJob().getById(quote.jobId);
    if (job == null) {
      throw Exception('Job not found for Quote ${quote.id}');
    }
    final customer = await DaoCustomer().getById(job.customerId);
    if (customer == null) {
      throw Exception('Customer not found for Job ${job.id}');
    }

    final contact = await DaoContact().getPrimaryForJob(job.id);
    return JobAndCustomer(job: job, customer: customer, contact: contact);
  }
}
