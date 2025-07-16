/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// quote_list_screen.dart
import 'dart:async';

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
import '../widgets/select/hmb_filter_line.dart';
import 'quote_card.dart';
import 'quote_details_screen.dart';

class QuoteListScreen extends StatefulWidget {
  const QuoteListScreen({super.key, this.job});

  final Job? job;
  @override
  _QuoteListScreenState createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends DeferredState<QuoteListScreen> {
  // Local list of quotes.
  List<Quote> _quotes = [];
  var _listKey = GlobalKey<AnimatedListState>();

  Job? selectedJob;
  Customer? selectedCustomer;
  String? filterText;
  // When false (default) do not display approved/rejected quotes.
  var _includeApproved = true;
  var _includeRejected = false;
  var _includeInvoiced = false;
  final _duration = const Duration(milliseconds: 300);

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Quotes');
    await _loadQuotes();
  }

  // Load quotes from the DAO.
  Future<void> _loadQuotes() async {
    final quotes = await _fetchFilteredQuotes();
    _quotes = quotes;

    /// force the AnimatedList to be fully rebuilt without animations.
    _listKey = GlobalKey<AnimatedListState>();
    setState(() {});
  }

  Future<List<Quote>> _fetchFilteredQuotes() async {
    var filteredQuotes = await DaoQuote().getByFilter(filterText);

    // Job filter
    if (selectedJob != null) {
      filteredQuotes = filteredQuotes
          .where((q) => q.jobId == selectedJob!.id)
          .toList();
    }

    // Customer filter
    if (selectedCustomer != null) {
      final forCustomer = <Quote>[];
      for (final quote in filteredQuotes) {
        final job = await DaoJob().getById(quote.jobId);
        if (job?.customerId == selectedCustomer!.id) {
          forCustomer.add(quote);
        }
      }
      filteredQuotes = forCustomer;
    }

    final invoiced = filteredQuotes
        .where((q) => q.state == QuoteState.invoiced)
        .toList();
    final approved = filteredQuotes
        .where((q) => q.state == QuoteState.approved)
        .toList();
    final rejected = filteredQuotes
        .where((q) => q.state == QuoteState.rejected)
        .toList();

    final awaiting = filteredQuotes
        .where(
          (q) => q.state == QuoteState.reviewing || q.state == QuoteState.sent,
        )
        .toList();

    final quotes = <Quote>[];
    if (_includeInvoiced) {
      quotes.addAll(invoiced);
    }

    if (_includeApproved) {
      quotes.addAll(approved);
    }
    if (_includeRejected) {
      quotes.addAll(rejected);
    }

    quotes.addAll(awaiting);

    return quotes..sort((a, b) => -a.modifiedDate.compareTo(b.modifiedDate));
  }

  Future<void> _createQuote() async {
    final job = await SelectJobDialog.show(context);
    if (job == null) {
      return;
    }
    if (mounted) {
      final quoteOptions = await selectTaskToQuote(
        context: context,
        job: job,
        title: 'Tasks to quote',
      );
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
          // Assume create returns the new Quote.
          final newQuote = await DaoQuote().create(job, quoteOptions);
          // Insert the new quote at the beginning (or any desired position).
          setState(() {
            _quotes.insert(0, newQuote);
          });
          _listKey.currentState?.insertItem(0, duration: _duration);
        } catch (e) {
          HMBToast.error(
            'Failed to create quote: $e',
            acknowledgmentRequired: true,
          );
        }
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
            hint: "Don't delete the quote",
            onPressed: () => Navigator.of(context).pop(false),
          ),
          HMBButton(
            label: 'Delete',
            hint: 'Delete this quote',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      try {
        await DaoQuote().delete(quote.id);
        HMBToast.info('Quote deleted successfully.');
        _removeQuoteFromList(quote);
      } catch (e) {
        HMBToast.error('Failed to delete quote: $e');
      }
    }
  }

  // // Called when a quote is deleted
  void _removeQuoteFromList(Quote removedQuote) {
    final index = _quotes.indexWhere((q) => q.id == removedQuote.id);
    if (index != -1) {
      final removedItem = _quotes.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => ClipRect(
          child: FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              child: QuoteCard(
                key: ValueKey(removedItem.id),
                quote: removedItem,
                onDelete: () {},
                onStateChanged: (_) {},
              ),
            ),
          ),
        ),
        duration: _duration,
      );
    }
  }

  Future<void> _onFilterChanged(String value) async {
    filterText = value;
    await _loadQuotes();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 80,
      title: HMBFilterLine(
        lineBuilder: (context) => HMBSearchWithAdd(
          onSearch: (filter) => unawaited(_onFilterChanged(filter ?? '')),
          onAdd: _createQuote,
        ),
        sheetBuilder: _buildFilterSheet,
        onClearAll: () async {
          _includeApproved = true;
          _includeRejected = false;
          _includeInvoiced = false;
          await _loadQuotes();
        },
        isActive: () =>
            !_includeApproved || _includeRejected || _includeInvoiced,
      ),
    ),
    body: DeferredBuilder(
      this,
      builder: (context) => Column(
        children: [
          Expanded(
            child: _quotes.isEmpty
                ? const Center(child: Text('No quotes found.'))
                : AnimatedList(
                    key: _listKey,
                    initialItemCount: _quotes.length,
                    itemBuilder: (context, index, animation) {
                      final quote = _quotes[index];
                      return SizeTransition(
                        sizeFactor: animation,
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    QuoteDetailsScreen(quoteId: quote.id),
                              ),
                            );
                          },
                          child: QuoteCard(
                            key: ValueKey(quote.id),
                            quote: quote,
                            // ignore: discarded_futures
                            onDelete: () => _deleteQuote(quote),
                            // ignore: discarded_futures
                            onStateChanged: (_) async {
                              await _fetchFilteredQuotes();
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );

  List<Quote> removeAll(List<Quote> focus, List<Quote> other) {
    final bIds = other.map((b) => b.id).toSet();
    focus.removeWhere((a) => bIds.contains(a.id));
    return focus;
  }

  Widget _buildFilterSheet(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),

    /// StatefulBuilder so that the switches reflect  changes
    child: StatefulBuilder(
      builder: (context, setModalState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Filter Quotes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Include Approved'),
            value: _includeApproved,
            onChanged: (val) async {
              _includeApproved = val;
              setModalState(() {});
              await _loadQuotes();
            },
          ),
          SwitchListTile(
            title: const Text('Include Invoiced'),
            value: _includeInvoiced,
            onChanged: (val) async {
              _includeInvoiced = val;
              setModalState(() {});
              await _loadQuotes();
            },
          ),
          SwitchListTile(
            title: const Text('Include Rejected'),
            value: _includeRejected,
            onChanged: (val) async {
              _includeRejected = val;
              setModalState(() {});
              await _loadQuotes();
            },
          ),
        ],
      ),
    ),
  );
}
