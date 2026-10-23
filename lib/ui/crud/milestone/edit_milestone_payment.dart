// ignore_for_file: async_return_with_no_await

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

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/invoice.dart';
import '../../../entity/milestone.dart';
import '../../../entity/quote.dart';
import '../../../util/dart/list_ex.dart';
import '../../../util/dart/money_ex.dart';
import '../../invoicing/create_invoice_ui.dart';
import '../../invoicing/prepare_invoice_screen.dart';
import '../../widgets/blocking_ui.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/icons/hmb_add_button.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/text/hmb_text.dart';
import 'milestone_tile.dart';

class EditMilestonesScreen extends StatefulWidget {
  final int quoteId;

  const EditMilestonesScreen({required this.quoteId, super.key});

  @override
  _EditMilestonesScreenState createState() => _EditMilestonesScreenState();
}

class _EditMilestonesScreenState extends DeferredState<EditMilestonesScreen> {
  late Quote quote;
  List<Milestone> milestones = [];
  final daoMilestonePayment = DaoMilestone();
  Money totalAllocated = MoneyEx.zero;
  var _errorMessage = '';
  int? editingMilestoneId; // Track which milestone is currently being edited

  @override
  Future<void> asyncInitState() async {
    await _loadData();
  }

  Future<void> _saveSchedule() async {
    try {
      await BlockingUI().runAndWait(
        () => daoMilestonePayment.saveSchedule(quote.id, milestones),
      );
    } on Exception catch (error) {
      HMBToast.error('Unable to save milestones: $error');
      await _loadData();
    }
  }

  Future<void> _loadData() async {
    quote = (await DaoQuote().getById(widget.quoteId))!;
    milestones = await daoMilestonePayment.getByQuoteId(widget.quoteId);
    _calculateTotals();
  }

  void _calculateTotals() {
    _recalcAllocated();
    final difference = quote.totalAmount - totalAllocated;

    if (milestones.isEmpty) {
      _errorMessage = 'Add a milestone to begin';
      return;
    }
    if (!difference.isZero) {
      if (difference.isNegative) {
        _errorMessage =
            '''Total milestone amounts exceed the Quotation Total by ${-difference}''';
      } else {
        _errorMessage =
            '''Total milestone amounts are less than the Quote total by $difference''';
      }
    } else {
      _errorMessage = '';
    }
  }

  void _recalcAllocated() {
    totalAllocated = milestones.fold<Money>(
      MoneyEx.zero,
      (sum, m) => sum + (m.paymentAmount),
    );
  }

  Future<void> _addMilestone() async {
    final newMilestone = Milestone.forInsert(
      quoteId: quote.id,
      milestoneNumber: milestones.length + 1,
      paymentPercentage: Percentage.zero,
      paymentAmount: MoneyEx.zero,
      milestoneDescription: '',
    );
    milestones.add(newMilestone);
    await _redistributeAmounts();

    setState(() {});
  }

  /// Distribute amounts evenly amongst unedited milestones.
  Future<void> _redistributeAmounts() async {
    final uninvoicedMilestones = milestones.where((m) => m.invoiceId == null);

    if (uninvoicedMilestones.isEmpty) {
      await _saveSchedule();
      return;
    }

    // Separate edited and unedited milestones
    final editedMilestones = uninvoicedMilestones
        .where((m) => m.edited)
        .toList();
    final uneditedMilestones = uninvoicedMilestones
        .where((m) => !m.edited)
        .toList();

    // Calculate how much is already allocated by edited milestones
    final allocatedByEdited = editedMilestones.fold<Money>(
      MoneyEx.zero,
      (sum, m) => sum + (m.paymentAmount),
    );

    // total quote - edited - invoiced
    final invoicedSum = milestones.fold<Money>(
      MoneyEx.zero,
      (sum, m) =>
          sum + ((m.invoiceId != null) ? m.paymentAmount : MoneyEx.zero),
    );

    final unallocated = quote.totalAmount - allocatedByEdited - invoicedSum;
    final remainingForUnedited = unallocated.isNegative
        ? MoneyEx.zero
        : unallocated;

    if (uneditedMilestones.isEmpty) {
      await _saveSchedule();
      _calculateTotals();
      setState(() {});
      return;
    }

    final count = uneditedMilestones.length;
    final amountPerMilestone = count > 0
        ? remainingForUnedited.divideByFixed(
            Fixed.fromInt(count, decimalDigits: 0),
          )
        : MoneyEx.zero;

    for (final milestone in uneditedMilestones) {
      milestone
        ..paymentAmount = amountPerMilestone
        ..paymentPercentage = amountPerMilestone.percentageOf(
          quote.totalAmount,
        );
    }

    _recalcAllocated();

    final difference = quote.totalAmount - totalAllocated;
    final lastMilestone = milestones.lastWhereOrNull(
      (m) => m.invoiceId == null,
    );

    if (lastMilestone != null &&
        !lastMilestone.edited &&
        !unallocated.isNegative) {
      lastMilestone
        ..paymentAmount = (lastMilestone.paymentAmount) + difference
        ..paymentPercentage = lastMilestone.paymentAmount.percentageOf(
          quote.totalAmount,
        );
    }
    await _saveSchedule();
    _calculateTotals();
    setState(() {});
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final invoicedMilestones =
        milestones.where((m) => m.invoiceId != null).length - 1;
    if (oldIndex < invoicedMilestones || newIndex <= invoicedMilestones) {
      HMBToast.info("You can't re-order invoiced milestones");
      return;
    }

    final movedMilestone = milestones.removeAt(oldIndex);
    milestones.insert(newIndex, movedMilestone);

    // Update milestone numbers
    for (var i = 0; i < milestones.length; i++) {
      milestones[i].milestoneNumber = i + 1;
    }
    await _saveSchedule();

    setState(() {});
  }

  /// Called by a tile when the user clicks 'save' on that tile.
  /// We now apply changes and run redistribution if needed.
  Future<void> _onMilestoneSave(Milestone milestone) async {
    final index = milestones.indexWhere((m) => m.id == milestone.id);
    milestones[index] = milestone;

    // Redistribute or recalc totals as needed
    await _redistributeAmounts();
    setState(() {});
  }

  Future<void> _onMilestoneDeleted(Milestone milestone) async {
    if (milestone.invoiceId != null) {
      _showMessage('Cannot delete an invoiced milestone.');
      return;
    }
    milestones.remove(milestone);
    await _redistributeAmounts();
    setState(() {});
  }

  /// Called by a tile when it enters or leaves edit mode.
  void _onEditingStatusChanged({
    required Milestone milestone,
    required bool isEditing,
  }) {
    setState(() {
      editingMilestoneId = isEditing ? milestone.id : null;
    });
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => Scaffold(
      appBar: AppBar(
        title: const Text('Milestone payments'),
        actions: [
          HMBButtonAdd(
            enabled: true,
            hint: 'Add Milestone',
            onAdd: _addMilestone,
          ),
        ],
      ),
      body: HMBColumn(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HMBText('Quote Total: ${quote.totalAmount}'),
                Text('Quote #${quote.bestNumber} — ${quote.summary}'),
                const Text(
                  'Split the quote into progress payments. '
                  'After approval, invoice each milestone when it is due.',
                ),
              ],
            ),
          ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: ReorderableListView(
              // padding: const EdgeInsets.only(right: 28),
              onReorderItem: _onReorder,
              children: List.generate(milestones.length, (index) {
                final milestone = milestones[index];
                return MilestoneTile(
                  key: ValueKey(milestone.id),
                  milestone: milestone,
                  quoteTotal: quote.totalAmount,
                  onDelete: _onMilestoneDeleted,
                  onSave: _onMilestoneSave,
                  canEdit: true,
                  onInvoice:
                      // ignore: unnecessary_async
                      (milestone) async =>
                          _onMilestoneInvoice(context, milestone),
                  // If editingMilestoneId is set and not equal to this
                  //milestone's id,
                  // then this tile is grayed out.
                  isOtherTileEditing:
                      editingMilestoneId != null &&
                      editingMilestoneId != milestone.id,
                  // Add the editing status changed callback
                  onEditingStatusChanged: _onEditingStatusChanged,
                );
              }),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _onMilestoneInvoice(
    BuildContext context,
    Milestone milestone,
  ) async {
    final job = await BlockingUI().runAndWait(
      () => DaoJob().getJobForQuote(milestone.quoteId),
    );
    if (!context.mounted) {
      return;
    }
    final invoice = await Navigator.of(context).push<Invoice>(
      MaterialPageRoute(
        builder: (_) =>
            PrepareInvoiceScreen(jobId: job.id, milestoneId: milestone.id),
      ),
    );
    if (invoice != null && context.mounted) {
      await openPreparedInvoice(context, invoice);
    }
    if (!mounted) {
      return;
    }
    await BlockingUI().runAndWait(_loadData);
    if (mounted) {
      setState(() {});
    }
  }
}
