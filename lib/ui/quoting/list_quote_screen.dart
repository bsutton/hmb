// quote_list_screen.dart
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/util.g.dart';
import '../invoicing/dialog_select_tasks.dart';
import '../invoicing/select_job_dialog.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_search.dart';
import '../widgets/hmb_toast.dart';
import 'quote_card.dart';
import 'quote_details_screen.dart';

class QuoteListScreen extends StatefulWidget {
  const QuoteListScreen({super.key});

  @override
  _QuoteListScreenState createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends DeferredState<QuoteListScreen> {
  // Maintain a local list of quotes.
  List<Quote> _quotes = [];

  Job? selectedJob;
  Customer? selectedCustomer;
  String? filterText;
  // When false (the default) we do not display approved/rejected quotes.
  bool includeApprovedRejected = false;

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Quotes');
    await _loadQuotes();
  }

  // Load quotes once from the DAO.
  Future<void> _loadQuotes() async {
    _quotes = await _fetchFilteredQuotes();
    setState(() {});
  }

  Future<List<Quote>> _fetchFilteredQuotes() async {
    var quotes = await DaoQuote().getByFilter(filterText);
    if (selectedJob != null) {
      quotes = quotes.where((q) => q.jobId == selectedJob!.id).toList();
    }
    if (selectedCustomer != null) {
      quotes = await Future.wait(
        quotes.map((q) async {
          final job = await DaoJob().getById(q.jobId);
          return job?.customerId == selectedCustomer!.id ? q : null;
        }),
      ).then((list) => list.whereType<Quote>().toList());
    }
    if (!includeApprovedRejected) {
      quotes =
          quotes
              .where(
                (q) =>
                    (q.state != QuoteState.approved) &&
                    (q.state != QuoteState.rejected),
              )
              .toList();
    }
    return quotes;
  }

  Future<void> _createQuote() async {
    final job = await SelectJobDialog.show(context);
    if (job == null) return;
    final quoteOptions = await showQuote(context: context, job: job);
    if (quoteOptions != null) {
      try {
        if (!quoteOptions.billBookingFee &&
            quoteOptions.selectedTaskIds.isEmpty) {
          HMBToast.error(
            'You must select a task or the booking fee',
            acknowledgmentRequired: true,
          );
          return;
        }
        await DaoQuote().create(job, quoteOptions);
      } catch (e) {
        HMBToast.error(
          'Failed to create quote: $e',
          acknowledgmentRequired: true,
        );
      }
      // Reload the list if needed.
      await _loadQuotes();
    }
  }

  Future<void> _deleteQuote(Quote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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
        // Remove the quote locally.
        setState(() {
          _quotes.removeWhere((q) => q.id == quote.id);
        });
      } catch (e) {
        HMBToast.error('Failed to delete quote: $e');
      }
    }
  }

  Future<void> _onFilterChanged(String value) async {
    filterText = value;
    await _loadQuotes();
  }

  // Called from QuoteSummaryCard after its removal animation.
  void _removeQuoteFromList(Quote removedQuote) {
    setState(() {
      _quotes.removeWhere((q) => q.id == removedQuote.id);
    });
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
    body: DeferredBuilder(
      this,
      builder:
          (context) => Column(
            children: [
              // --- FILTER SECTION ---
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Filter Quotes',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) async => _onFilterChanged(value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        const Text('Include Approved/Rejected'),
                        Switch(
                          value: includeApprovedRejected,
                          onChanged: (val) async {
                            includeApprovedRejected = val;
                            await _loadQuotes();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // --- END FILTER SECTION ---
              Expanded(
                child:
                    _quotes.isEmpty
                        ? const Center(child: Text('No quotes found.'))
                        : ListView.builder(
                          itemCount: _quotes.length,
                          itemBuilder: (context, index) {
                            final quote = _quotes[index];
                            return GestureDetector(
                              onTap: () async {
                                // Navigate without forcing a full reload.
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder:
                                        (context) => QuoteDetailsScreen(
                                          quoteId: quote.id,
                                        ),
                                  ),
                                );
                                // Optionally, update only if necessary.
                              },
                              // Use a stable key based on quote.id.
                              child: QuoteSummaryCard(
                                key: ValueKey(quote.id),
                                quote: quote,
                                onDelete: () async => _deleteQuote(quote),
                                onStateChanged: _removeQuoteFromList,
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
    ),
  );
}
