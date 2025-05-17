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
import '../widgets/layout/layout.g.dart';
import 'quote_card.dart';
import 'quote_details_screen.dart';

class QuoteListScreen extends StatefulWidget {
  const QuoteListScreen({super.key});

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
  var _includeCompleted = false;
  final _duration = const Duration(milliseconds: 300);

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Quotes');
    await _loadQuotes();
  }

  // Load quotes from the DAO.
  Future<void> _loadQuotes() async {
    final quotes = await _fetchFilteredQuotes();
    setState(() {
      _quotes = quotes;

      /// force the AnimatedList to be full rebuilt without animations.
      _listKey = GlobalKey<AnimatedListState>();
    });
  }

  Future<List<Quote>> _fetchFilteredQuotes() async {
    var quotes = await DaoQuote().getByFilter(filterText);

    // Job filter
    if (selectedJob != null) {
      quotes = quotes.where((q) => q.jobId == selectedJob!.id).toList();
    }

    // Customer filter
    if (selectedCustomer != null) {
      final forCustomer = <Quote>[];
      for (final quote in quotes) {
        final job = await DaoJob().getById(quote.jobId);
        if (job?.customerId == selectedCustomer!.id) {
          forCustomer.add(quote);
        }
      }
      quotes = forCustomer;
    }

    // State filters
    if (!_includeApproved) {
      quotes = quotes.where((q) => q.state != QuoteState.approved).toList();
    }
    if (!_includeRejected) {
      quotes = quotes.where((q) => q.state != QuoteState.rejected).toList();
    }

    // Completed filter: exclude “completed” quotes if !_includeCompleted
    if (!_includeCompleted) {
      final notCompleted = <Quote>[];
      for (final quote in quotes) {
        // 1) any milestone for this quote?
        final milestones = await DaoMilestone().getByQuoteId(quote.id);
        if (milestones.isNotEmpty) {
          continue; // completed → skip
        }
        // 2) any invoice on the quote’s job?
        final invoices = await DaoInvoice().getByJobId(quote.jobId);
        if (invoices.isNotEmpty) {
          continue; // completed → skip
        }
        // still here? → not completed
        notCompleted.add(quote);
      }
      quotes = notCompleted;
    }

    return quotes;
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
        // _removeQuoteFromList(quote);
      } catch (e) {
        HMBToast.error('Failed to delete quote: $e');
      }
    }
  }

  // // Called when a QuoteCard signals removal (after an approve/reject action).
  // void _removeQuoteFromList(Quote removedQuote) {
  //   final index = _quotes.indexWhere((q) => q.id == removedQuote.id);
  //   if (index != -1) {
  //     final removedItem = _quotes.removeAt(index);
  //     _listKey.currentState?.removeItem(
  //       index,
  //       (context, animation) => ClipRect(
  //         child: FadeTransition(
  //           opacity: animation,
  //           child: SizeTransition(
  //             sizeFactor: animation,
  //             child: QuoteCard(
  //               key: ValueKey(removedItem.id),
  //               quote: removedItem,
  //               onDelete: () {},
  //               onStateChanged: (_) {},
  //             ),
  //           ),
  //         ),
  //       ),
  //       duration: _duration,
  //     );
  //   }
  // }

  Future<void> _onFilterChanged(String value) async {
    filterText = value;
    await _loadQuotes();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 80,
      title: HMBSearchWithAdd(
        onSearch: (filter) => unawaited(_onFilterChanged(filter ?? '')),
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
                    Row(
                      children: [
                        const Text('Approved'),
                        Switch(
                          value: _includeApproved,
                          onChanged: (val) async {
                            _includeApproved = val;
                            await _loadQuotes();
                            setState(() {});
                          },
                        ),
                        const HMBSpacer(width: true),
                        const Text('Completed'),
                        Switch(
                          value: _includeCompleted,
                          onChanged: (val) async {
                            _includeCompleted = val;
                            await _loadQuotes();
                            setState(() {});
                          },
                        ),
                        const HMBSpacer(width: true),
                        const Text('Rejected'),
                        Switch(
                          value: _includeRejected,
                          onChanged: (val) async {
                            _includeRejected = val;
                            await _loadQuotes();
                            setState(() {});
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
                                      builder:
                                          (context) => QuoteDetailsScreen(
                                            quoteId: quote.id,
                                          ),
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
}
