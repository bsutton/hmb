import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../../dao/dao_invoice_fixed_price.dart';
import '../../../dao/dao_milestone.dart';
import '../../../dao/dao_quote.dart';
import '../../../entity/milestone.dart';
import '../../../entity/quote.dart';
import '../../../util/list_ex.dart';
import '../../../util/money_ex.dart';
import '../../widgets/async_state.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/text/hmb_text.dart';
import 'milestone_tile.dart';

class EditMilestonesScreen extends StatefulWidget {
  const EditMilestonesScreen({required this.quoteId, super.key});
  final int quoteId;

  @override
  _EditMilestonesScreenState createState() => _EditMilestonesScreenState();
}

class _EditMilestonesScreenState
    extends AsyncState<EditMilestonesScreen, void> {
  late Quote quote;
  List<Milestone> milestones = [];
  final daoMilestonePayment = DaoMilestone();
  Money totalAllocated = MoneyEx.zero;
  String errorMessage = '';

  @override
  Future<void> asyncInitState() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    quote = (await DaoQuote().getById(widget.quoteId))!;
    milestones = await daoMilestonePayment.getByQuoteId(widget.quoteId);
    _calculateTotals();
  }

  void _calculateTotals() {
    totalAllocated = milestones.fold<Money>(
      MoneyEx.zero,
      (sum, m) => sum + (m.paymentAmount ?? MoneyEx.zero),
    );
    final difference = quote.totalAmount - totalAllocated;

    if (milestones.isEmpty) {
      errorMessage = 'Add a milestone to begin';
      return;
    }
    if (!difference.isZero) {
      errorMessage = 'Total milestone amounts do not equal the quote total.';
    } else {
      errorMessage = '';
    }
  }

  Future<void> _addMilestone() async {
    final newMilestone = Milestone.forInsert(
      quoteId: quote.id,
      milestoneNumber: milestones.length + 1,
      paymentPercentage: Percentage.zero,
      paymentAmount: MoneyEx.zero,
      milestoneDescription: '',
    );
    await DaoMilestone().insert(newMilestone);
    milestones.add(newMilestone);
    _redistributeAmounts();
    setState(() {});
  }

  void _redistributeAmounts() {
    final uninvoicedMilestones =
        milestones.where((m) => m.invoiceId == null).toList();

    if (uninvoicedMilestones.isEmpty) {
      return;
    }

    final allocatedAmount = milestones.fold<Money>(
      MoneyEx.zero,
      (sum, m) => sum + (m.invoiceId != null ? m.paymentAmount! : MoneyEx.zero),
    );

    final remainingAmount = quote.totalAmount - allocatedAmount;

    final amountPerMilestone = remainingAmount
        .divideByFixed(Fixed.fromInt(uninvoicedMilestones.length, scale: 0));

    for (final milestone in uninvoicedMilestones) {
      milestone
        ..paymentAmount = amountPerMilestone
        ..paymentPercentage =
            amountPerMilestone.percentageOf(quote.totalAmount);
    }

    _calculateTotals();
    setState(() {});
  }

  Future<void> _createInvoiceForNextMilestone() async {
    final nextMilestone = milestones.firstWhereOrNull(
      (m) => m.invoiceId == null,
    );

    if (nextMilestone == null) {
      HMBToast.info('All Invoices have already been genearted.');
      return;
    }

    // Assume createInvoiceFromMilestonePayment is defined elsewhere
    final invoice = await createInvoiceFromMilestonePayment(nextMilestone);
    nextMilestone
      ..invoiceId = invoice.id
      ..status = 'invoiced';
    await daoMilestonePayment.update(nextMilestone);
    _calculateTotals();
    setState(() {});
    _showMessage(
        'Invoice created for Milestone ${nextMilestone.milestoneNumber}.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _balanceTotals() async {
    final difference = quote.totalAmount - totalAllocated;

    final lastMilestone =
        milestones.lastWhereOrNull((m) => m.invoiceId == null);

    if (lastMilestone == null) {
      HMBToast.info(
          "You can't change totals after all invoices have been generated");
      return;
    }

    lastMilestone
      ..paymentAmount =
          (lastMilestone.paymentAmount ?? MoneyEx.zero) + difference
      ..paymentPercentage =
          lastMilestone.paymentAmount!.percentageOf(quote.totalAmount);

    await daoMilestonePayment.update(lastMilestone);
    _calculateTotals();
    setState(() {});
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final invoicedMilestones =
        milestones.where((m) => m.invoiceId != null).length;
    if (oldIndex < invoicedMilestones || newIndex <= invoicedMilestones) {
      // Prevent reordering of invoiced milestones
      return;
    }

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final movedMilestone = milestones.removeAt(oldIndex);
    milestones.insert(newIndex, movedMilestone);

    // Update milestone numbers
    for (var i = 0; i < milestones.length; i++) {
      milestones[i].milestoneNumber = i + 1;
      await daoMilestonePayment.update(milestones[i]);
    }

    setState(() {});
  }

  Future<void> _onMilestoneChanged(Milestone milestone) async {
    _calculateTotals();
    await DaoMilestone().update(milestone);
    setState(() {});
  }

  Future<void> _onMilestoneDeleted(Milestone milestone) async {
    if (milestone.invoiceId != null) {
      _showMessage('Cannot delete an invoiced milestone.');
      return;
    }
    milestones.remove(milestone);
    if (milestone.id != 0) {
      await daoMilestonePayment.delete(milestone.id);
    }
    _redistributeAmounts();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
      future: initialised,
      builder: (context, _) => Scaffold(
            appBar: AppBar(
              title: const Text('Edit Milestones'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.receipt),
                  tooltip: 'Create Invoice for Next Milestone',
                  onPressed: _createInvoiceForNextMilestone,
                ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: HMBText('Quote Total: ${quote.totalAmount}'),
                ),
                if (errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: ReorderableListView(
                    onReorder: _onReorder,
                    children: List.generate(milestones.length, (index) {
                      final milestone = milestones[index];
                      return MilestoneTile(
                        key: ValueKey(milestone.id),
                        milestone: milestone,
                        quoteTotal: quote.totalAmount,
                        onChanged: _onMilestoneChanged,
                        onDelete: _onMilestoneDeleted,
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Milestone'),
                    onPressed: _addMilestone,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    onPressed: _balanceTotals,
                    child: const Text('Balance Totals'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ));
}
