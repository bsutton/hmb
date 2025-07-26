/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart' hide StatefulBuilder;

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/app_title.dart';
import '../../util/format.dart';
import '../crud/base_full_screen/base_full_screen.g.dart';
import '../invoicing/dialog_select_tasks.dart';
import '../invoicing/select_job_dialog.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/widgets.g.dart';
import 'quote_card.dart';
import 'quote_details_screen.dart';

class QuoteListScreen extends StatefulWidget {
  const QuoteListScreen({super.key, this.job});

  final Job? job;

  @override
  State<QuoteListScreen> createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends State<QuoteListScreen> {
  Job? selectedJob;
  Customer? selectedCustomer;
  var _includeApproved = true;
  var _includeInvoiced = false;
  var _includeRejected = false;

  @override
  void initState() {
    super.initState();
    setAppTitle('Quotes');
    selectedJob = widget.job;
  }

  Future<List<Quote>> _fetchFilteredQuotes(String? filter) async {
    // Base text filter (from the built‑in search box):
    var quotes = await DaoQuote().getByFilter(filter);

    // Job filter
    if (selectedJob != null) {
      quotes = quotes.where((q) => q.jobId == selectedJob!.id).toList();
    }

    // Customer filter
    if (selectedCustomer != null) {
      final byCustomer = <Quote>[];
      for (final q in quotes) {
        final job = await DaoJob().getById(q.jobId);
        if (job?.customerId == selectedCustomer!.id) {
          byCustomer.add(q);
        }
      }
      quotes = byCustomer;
    }

    // Split by state
    final invoiced = quotes.where((q) => q.state == QuoteState.invoiced);
    final approved = quotes.where((q) => q.state == QuoteState.approved);
    final rejected = quotes.where((q) => q.state == QuoteState.rejected);
    final awaiting = quotes.where(
      (q) => q.state == QuoteState.reviewing || q.state == QuoteState.sent,
    );

    // Reassemble in desired order
    final result = <Quote>[];
    if (_includeInvoiced) {
      result.addAll(invoiced);
    }
    if (_includeApproved) {
      result.addAll(approved);
    }
    if (_includeRejected) {
      result.addAll(rejected);
    }
    result
      ..addAll(awaiting)
      // Most‑recent first
      ..sort((a, b) => -a.modifiedDate.compareTo(b.modifiedDate));
    return result;
  }

  Future<Quote?> _createQuote() async {
    Job? job;
    if (widget.job == null) {
      job = await SelectJobDialog.show(context);
      if (job == null) {
        return null;
      }
    } else {
      job = widget.job;
    }

    if (!mounted) {
      return null;
    }

    final opts = await selectTaskToQuote(
      context: context,
      job: job!,
      title: 'Tasks to Quote',
    );
    if (opts == null) {
      return null;
    }

    if (!opts.billBookingFee && opts.selectedTaskIds.isEmpty) {
      HMBToast.error(
        'You must select a task or the booking fee',
        acknowledgmentRequired: true,
      );
      return null;
    }

    try {
      return await DaoQuote().create(job, opts);
    } catch (e) {
      HMBToast.error(
        'Failed to create quote: $e',
        acknowledgmentRequired: true,
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => Surface(
    elevation: SurfaceElevation.e0,
    child: Column(
      children: [
        Expanded(
          child: EntityListScreen<Quote>(
            pageTitle: 'Quotes',
            showBackButton: widget.job != null,
            dao: DaoQuote(),
            title: (quote) => Text(
              'Quote #${quote.id} - Issued: ${formatDate(quote.createdDate)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            fetchList: _fetchFilteredQuotes,
            onAdd: _createQuote,
            onEdit: (q) => QuoteDetailsScreen(quoteId: q!.id),
            cardHeight: 280,
            background: (_) async => Colors.transparent,
            details: _buildQuoteCard,
            filterSheetBuilder: _buildFilterSheet,
            isFilterActive: () =>
                widget.job == null &&
                    (selectedJob != null || selectedCustomer != null) ||
                !_includeApproved ||
                !_includeInvoiced ||
                !_includeRejected,
            onFiltersCleared: () {
              selectedJob = widget.job;
              selectedCustomer = null;
              _includeApproved = true;
              _includeInvoiced = true;
              _includeRejected = true;
            },
          ),
        ),
      ],
    ),
  );

  Widget _buildQuoteCard(Quote quote) => QuoteCard(
    key: ValueKey(quote.id),
    quote: quote,
    onStateChanged: (_) => setState(() {}),
  );

  Widget _buildFilterSheet(void Function() onChange) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Job dropdown
        if (widget.job == null)
          HMBDroplist<Job>(
            title: 'Filter by Job',
            items: (f) => DaoJob().getActiveJobs(f),
            format: (j) => j.summary,
            required: false,
            selectedItem: () async => selectedJob,
            onChanged: (j) {
              selectedJob = j;
              onChange();
            },
          ),
        if (widget.job == null) const HMBSpacer(height: true),
        // Customer dropdown
        if (widget.job == null)
          HMBDroplist<Customer>(
            title: 'Filter by Customer',
            items: (f) => DaoCustomer().getByFilter(f),
            format: (c) => c.name,
            required: false,
            selectedItem: () async => selectedCustomer,
            onChanged: (c) {
              selectedCustomer = c;
              onChange();
            },
          ),
        if (widget.job == null) const HMBSpacer(height: true),
        // State switches
        SwitchListTile(
          title: const Text('Include Approved'),
          value: _includeApproved,
          onChanged: (v) {
            _includeApproved = v;
            onChange();
          },
        ),
        SwitchListTile(
          title: const Text('Include Invoiced'),
          value: _includeInvoiced,
          onChanged: (v) {
            _includeInvoiced = v;
            onChange();
          },
        ),
        SwitchListTile(
          title: const Text('Include Rejected'),
          value: _includeRejected,
          onChanged: (v) {
            _includeRejected = v;
            onChange();
          },
        ),
      ],
    ),
  );
}
