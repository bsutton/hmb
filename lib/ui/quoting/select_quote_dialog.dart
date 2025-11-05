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

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_contact.dart';
import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_quote.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../entity/quote.dart';
import '../widgets/icons/hmb_close_icon.dart';
import '../widgets/layout/layout.g.dart';

class SelectQuoteDialog extends StatefulWidget {
  const SelectQuoteDialog({super.key});

  @override
  _SelectQuoteDialogState createState() => _SelectQuoteDialogState();

  static Future<Quote?> show(BuildContext context) => showDialog<Quote?>(
    context: context,
    builder: (context) => const SelectQuoteDialog(),
  );
}

class _SelectQuoteDialogState extends State<SelectQuoteDialog> {
  var _showAllQuotes = false;
  var _showQuotesWithNoBillableItems = false;

  final _searchController = TextEditingController();
  var _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<List<CustomerAndQuote>> _fetchQuotes() => CustomerAndQuote.getQuotes(
    showAllQuotes: _showAllQuotes,
    showQuotesWithNoBillableItems: _showQuotesWithNoBillableItems,
  );

  List<CustomerAndQuote> _filterQuotes(List<CustomerAndQuote> quotes) {
    if (_searchQuery.isEmpty) {
      return quotes;
    }
    return quotes.where((cj) {
      final customerName = cj.customer.name.toLowerCase();
      final jobSummary = cj.job.summary.toLowerCase();
      final contactName = (cj.contactName ?? '').toLowerCase();

      return customerName.contains(_searchQuery) ||
          jobSummary.contains(_searchQuery) ||
          contactName.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    // Remove default dialog padding to allow full-screen
    insetPadding: EdgeInsets.zero,
    backgroundColor: Theme.of(context).canvasColor,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Select Quote'),
        actions: [HMBCloseIcon(onPressed: () async => Navigator.pop(context))],
      ),
      body: HMBColumn(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: HMBColumn(
              children: [
                CheckboxListTile(
                  title: const Text('Show all quotes'),
                  value: _showAllQuotes,
                  onChanged: (value) {
                    setState(() {
                      _showAllQuotes = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('Show quotes with no billable items'),
                  value: _showQuotesWithNoBillableItems,
                  onChanged: (value) {
                    setState(() {
                      _showQuotesWithNoBillableItems = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          Expanded(
            child: FutureBuilderEx<List<CustomerAndQuote>>(
              // ignore: discarded_futures
              future: _fetchQuotes(),
              builder: (context, quotes) {
                if (quotes == null || quotes.isEmpty) {
                  return const Center(child: Text('No quotes found.'));
                }

                final filteredQuotes = _filterQuotes(quotes);

                if (filteredQuotes.isEmpty) {
                  return const Center(
                    child: Text('No matches for your search.'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredQuotes.length,
                  itemBuilder: (context, index) {
                    final current = filteredQuotes[index];
                    return ListTile(
                      title: Text(current.job.summary),
                      subtitle: HMBColumn(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer: ${current.customer.name}'),
                          if (current.contactName != null)
                            Text('Contact: ${current.contactName}'),
                        ],
                      ),
                      onTap: () => Navigator.pop(context, current.quote),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class CustomerAndQuote {
  final Customer customer;
  final Job job;
  final Quote quote;
  final String? contactName;

  CustomerAndQuote(this.customer, this.quote, this.job, {this.contactName});

  static Future<List<CustomerAndQuote>> getQuotes({
    required bool showAllQuotes,
    required bool showQuotesWithNoBillableItems,
  }) async {
    List<Quote> quotes;

    if (showAllQuotes) {
      quotes = await DaoQuote().getAll();
    } else {
      quotes = await DaoQuote()
          .getQuotesWithoutMilestones(); // Fetch active quotes
    }

    final quoteList = <CustomerAndQuote>[];

    for (final quote in quotes) {
      final customer = await DaoCustomer().getByQuote(quote.id);
      if (customer == null) {
        continue;
      }

      final job = await DaoJob().getById(quote.jobId);

      // Fetch the primary contact for the quote
      final contact = await DaoContact().getPrimaryForQuote(quote.id);
      final contactName = contact?.fullname;

      quoteList.add(
        CustomerAndQuote(customer, quote, job!, contactName: contactName),
      );
    }

    return quoteList;
  }
}
