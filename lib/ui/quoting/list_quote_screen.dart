import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_job.dart';
import '../../dao/dao_quote.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../entity/quote.dart';
import '../invoicing/dialog_select_tasks.dart';
import '../invoicing/select_job_dialog.dart';
import '../widgets/async_state.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/hmb_add_button.dart';
import '../widgets/hmb_toast.dart';
import 'quote_card.dart';

class QuoteListScreen extends StatefulWidget {
  const QuoteListScreen({super.key});

  @override
  _QuoteListScreenState createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends AsyncState<QuoteListScreen, void> {
  late Future<List<Quote>> _quotes;
  final TextEditingController _filterController = TextEditingController();

  Job? selectedJob;
  Customer? selectedCustomer;
  String? filterText;

  @override
  Future<void> asyncInitState() async {
    await _refreshQuoteList();
  }

  Future<void> _refreshQuoteList() async {
    setState(() {
      _quotes = _fetchFilteredQuotes();
    });
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

    return quotes;
  }

  Future<void> _createQuote() async {
    final job = await showDialog<Job?>(
      context: context,
      builder: (context) => const SelectJobDialog(),
    );

    if (job == null) {
      return;
    }

    if (mounted) {
      final invoiceOptions = await showQuote(context: context, job: job);

      if (invoiceOptions != null) {
        try {
          if (!invoiceOptions.billBookingFee &&
              invoiceOptions.selectedTaskIds.isEmpty) {
            HMBToast.error('You must select a task or the booking Fee',
                acknowledgmentRequired: true);
            return;
          }
          await DaoQuote().create(job, invoiceOptions);
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          HMBToast.error('Failed to create quote: $e',
              acknowledgmentRequired: true);
        }
        await _refreshQuoteList();
      }
    }
  }

  Future<void> _deleteQuote(Quote quote, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quote'),
        content: const Text('Are you sure you want to delete this quote?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Delete'),
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
    setState(() {
      filterText = value;
    });
    await _refreshQuoteList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Quotes'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshQuoteList,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: HMBTextField(
                controller: _filterController,
                labelText: 'Filters',
                // hint: 'Search quotes by number, job, or customer...',
                onChanged: (filter) async => _onFilterChanged(filter ?? ''),
              ),
            ),
            Expanded(
              child: FutureBuilderEx<List<Quote>>(
                future: _quotes,
                builder: (context, quotes) {
                  if (quotes!.isEmpty) {
                    return const Center(child: Text('No quotes found.'));
                  }

                  return ListView.builder(
                    itemCount: quotes.length,
                    itemBuilder: (context, index) => QuoteCard(
                      quote: quotes[index],
                      onDeleteQuote: () async =>
                          _deleteQuote(quotes[index], context),
                      onEditQuote: (quote) async {
                        setState(_refreshQuoteList);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton:
            HMBButtonAdd(onPressed: _createQuote, enabled: true),
      );
}
