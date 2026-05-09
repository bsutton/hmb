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

// lib/src/ui/receipt/receipt_edit_screen.dart
import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/money_ex.dart';
import '../../test_keys.dart';
import '../../widgets/fields/fields.g.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/select/hmb_select_job.dart';
import '../../widgets/select/hmb_select_supplier.dart';
import '../../widgets/widgets.g.dart';
import '../base_full_screen/edit_entity_screen.dart';
import '../task/photo_crud.dart';

class ReceiptEditScreen extends StatefulWidget {
  final Receipt? receipt;

  const ReceiptEditScreen({super.key, this.receipt});

  @override
  State<ReceiptEditScreen> createState() => _ReceiptEditScreenState();
}

class _ReceiptEditScreenState extends DeferredState<ReceiptEditScreen>
    implements EntityState<Receipt> {
  late DateTime _date;
  final _selectedJob = SelectedJob();
  int? _supplierId;

  @override
  Receipt? currentEntity;

  // NEW: selector state
  final selectedSupplier = SelectedSupplier();

  late HMBMoneyEditingController _totalExclCtrl;
  late HMBMoneyEditingController _taxCtrl;
  late HMBMoneyEditingController _totalInclCtrl;
  late PhotoController<Receipt> _photoCtrl;
  final _linkedTaskItemIds = <int>{};
  var _linkableTaskItems = <TaskItem>[];
  final _jobAllocations = <_ReceiptJobAllocationEditor>[];

  var _isCalculating = false;

  var _taxExHasUserValue = true;
  var _taxHasUserValue = true;
  var _taxIncHasUserValue = true;

  final _taxExFocus = FocusNode();
  final _taxFocus = FocusNode();
  final _taxIncFocus = FocusNode();

  @override
  Future<void> asyncInitState() async {
    currentEntity = widget.receipt;
    _date = currentEntity?.receiptDate ?? DateTime.now();
    _selectedJob.jobId = currentEntity?.jobId;
    _supplierId = currentEntity?.supplierId;
    selectedSupplier.selected = _supplierId;

    // Tax Exc
    _totalExclCtrl = HMBMoneyEditingController(
      money: currentEntity?.totalExcludingTax,
    );
    _taxExHasUserValue = currentEntity?.totalExcludingTax.isNonZero ?? false;
    _totalExclCtrl.addListener(() {
      if (!_isCalculating) {
        _taxExHasUserValue = !_totalExclCtrl.text.isBlank();
        if (_jobAllocations.length == 1 && _selectedJob.jobId != null) {
          _jobAllocations.single
            ..jobId = _selectedJob.jobId
            ..amount = _totalExclCtrl.money ?? MoneyEx.zero;
        }
        _recalculate();
      }
    });

    // Tax
    _taxCtrl = HMBMoneyEditingController(money: currentEntity?.tax);
    _taxHasUserValue = currentEntity?.totalExcludingTax.isNonZero ?? false;
    _taxCtrl.addListener(() {
      if (!_isCalculating) {
        _taxHasUserValue = !_taxCtrl.text.isBlank();
        _recalculate();
      }
    });

    /// Tax inc
    _totalInclCtrl = HMBMoneyEditingController(
      money: currentEntity?.totalIncludingTax,
    );
    _taxIncHasUserValue = currentEntity?.totalExcludingTax.isNonZero ?? false;
    _totalInclCtrl.addListener(() {
      if (!_isCalculating) {
        _taxIncHasUserValue = !_totalInclCtrl.text.isBlank();
        _recalculate();
      }
    });

    _photoCtrl = PhotoController<Receipt>(
      parent: currentEntity,
      parentType: ParentType.receipt,
    );
    if (currentEntity != null) {
      _linkedTaskItemIds.addAll(
        await DaoReceipt().getLinkedTaskItemIds(currentEntity!.id),
      );
      final allocations = await DaoReceipt().getJobAllocations(
        currentEntity!.id,
      );
      _jobAllocations.addAll(
        allocations.map(
          (allocation) => _ReceiptJobAllocationEditor(
            jobId: allocation.jobId,
            amount: allocation.amount,
          ),
        ),
      );
    }
    if (_jobAllocations.isEmpty && currentEntity != null) {
      _jobAllocations.add(
        _ReceiptJobAllocationEditor(
          jobId: currentEntity!.jobId,
          amount: currentEntity!.totalExcludingTax,
        ),
      );
    }
    await _reloadLinkableTaskItems();
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (_) => EntityEditScreen<Receipt>(
      entityName: 'Receipt',
      dao: DaoReceipt(),
      entityState: this,
      editor: (e, {required isNew}) => _buildEditor(),
      crossValidator: _validateTotals,
    ),
  );

  Widget _buildEditor() => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Date
      HMBDateTimeField(
        key: TestKeys.receiptDateField,
        mode: HMBDateTimeFieldMode.dateOnly,
        label: 'Receipt Date',
        initialDateTime: _date,
        onChanged: (v) => _date = v,
      ),

      // Job dropdown (unchanged)
      HMBSelectJob(
        key: TestKeys.receiptPrimaryJobSelector,
        selectedJob: _selectedJob,
        required: true,
        onSelected: (job) {
          setState(() {
            _selectedJob.jobId = job?.id;
            if (_jobAllocations.length <= 1) {
              _jobAllocations
                ..clear()
                ..add(
                  _ReceiptJobAllocationEditor(
                    jobId: job?.id,
                    amount: _totalExclCtrl.money ?? MoneyEx.zero,
                  ),
                );
            }
          });
          unawaited(_reloadLinkableTaskItems());
        },
      ),
      // SUPPLIER: now using your SelectSupplier widget
      HMBSelectSupplier(
        key: TestKeys.receiptSupplierSelector,
        selectedSupplier: selectedSupplier,
        required: true,

        onSelected: (supplier) {
          setState(() {
            _supplierId = supplier?.id;
            selectedSupplier.selected = supplier?.id;
          });
          unawaited(_reloadLinkableTaskItems());
        },
      ),

      // MONEY FIELDS: dollars entry
      HMBMoneyField(
        fieldKey: TestKeys.receiptTotalIncludingTaxField,
        controller: _totalInclCtrl,
        labelText: 'Total Incl. Tax',
        fieldName: 'Total Including Tax',
        focusNode: _taxIncFocus,
      ),
      HMBMoneyField(
        fieldKey: TestKeys.receiptTaxField,
        controller: _taxCtrl,
        labelText: 'Tax',
        fieldName: 'Tax',
        focusNode: _taxFocus,
      ),
      HMBMoneyField(
        fieldKey: TestKeys.receiptTotalExcludingTaxField,
        controller: _totalExclCtrl,
        labelText: 'Total Excl. Tax',
        fieldName: 'Total Excluding Tax',
        focusNode: _taxExFocus,
      ),
      _buildJobAllocations(),
      _buildTaskItemLinks(),

      // Photos
      PhotoCrud<Receipt>(
        key: ValueKey(currentEntity?.id),
        parentName: 'Receipt',
        parentType: ParentType.receipt,
        controller: _photoCtrl,
      ),
    ],
  );

  @override
  Future<Receipt> forUpdate(Receipt receipt) async => receipt.copyWith(
    jobId: _selectedJob.jobId,
    supplierId: _supplierId,
    totalExcludingTax: MoneyEx.tryParse(_totalExclCtrl.text),
    tax: MoneyEx.tryParse(_taxCtrl.text),
    totalIncludingTax: MoneyEx.tryParse(_totalInclCtrl.text),
  );

  @override
  Future<Receipt> forInsert() async => Receipt.forInsert(
    receiptDate: _date,
    jobId: _selectedJob.jobId!,
    supplierId: _supplierId!,
    totalExcludingTax: MoneyEx.tryParse(_totalExclCtrl.text),
    tax: MoneyEx.tryParse(_taxCtrl.text),
    totalIncludingTax: MoneyEx.tryParse(_totalInclCtrl.text),
  );

  @override
  Future<void> postSave(_) async {
    // update the controller to point at the newly‐saved entity
    _photoCtrl = PhotoController<Receipt>(
      parent: currentEntity,
      parentType: ParentType.receipt,
    );
    if (currentEntity != null) {
      await DaoReceipt().replaceTaskItemLinks(
        currentEntity!.id,
        _linkedTaskItemIds,
      );
      await DaoReceipt().replaceJobAllocations(
        currentEntity!.id,
        _jobAllocations.map(
          (allocation) => ReceiptJobAllocation.forInsert(
            receiptId: currentEntity!.id,
            jobId: allocation.jobId!,
            amount: allocation.amount,
          ),
        ),
      );
    }
    await _photoCtrl.load();
    await _reloadLinkableTaskItems();
    setState(() {});
  }

  Widget _buildTaskItemLinks() {
    final jobId = _selectedJob.jobId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Linked task items',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          'Optional. Select the purchased items this receipt covers.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (jobId == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Select a job before linking task items.'),
          )
        else if (_linkableTaskItems.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No completed buy items are available for this job and supplier.',
            ),
          )
        else
          ..._linkableTaskItems.map(
            (item) => CheckboxListTile(
              key: TestKeys.receiptTaskItemCheckbox(item.id),
              contentPadding: EdgeInsets.zero,
              title: Text(item.description),
              subtitle: Text(_formatTaskItemCost(item)),
              value: _linkedTaskItemIds.contains(item.id),
              onChanged: (selected) {
                setState(() {
                  if (selected ?? false) {
                    _linkedTaskItemIds.add(item.id);
                  } else {
                    _linkedTaskItemIds.remove(item.id);
                  }
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildJobAllocations() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Text(
        'Job cost allocation',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(
        'Split this supplier receipt across jobs when one purchase covers '
        'more than one job.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < _jobAllocations.length; i++)
        _buildJobAllocationRow(i),
      HMBButton.smallWithIcon(
        key: TestKeys.receiptAddJobAllocationButton,
        label: 'Add Job',
        hint: 'Allocate part of this receipt to another job.',
        icon: const Icon(Icons.add),
        onPressed: () {
          setState(() {
            _jobAllocations.add(
              _ReceiptJobAllocationEditor(amount: MoneyEx.zero),
            );
          });
        },
      ),
    ],
  );

  Widget _buildJobAllocationRow(int index) {
    final allocation = _jobAllocations[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: HMBSelectJob(
                  key: TestKeys.receiptJobAllocationSelector(index),
                  title: 'Allocated Job',
                  selectedJob: allocation.selectedJob,
                  required: true,
                  onSelected: (job) {
                    setState(() {
                      allocation.jobId = job?.id;
                    });
                  },
                ),
              ),
              if (_jobAllocations.length > 1)
                IconButton(
                  key: TestKeys.receiptJobAllocationRemove(index),
                  tooltip: 'Remove job allocation',
                  onPressed: () {
                    setState(() {
                      _jobAllocations.removeAt(index);
                    });
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          HMBMoneyField(
            fieldKey: TestKeys.receiptJobAllocationAmountField(index),
            controller: allocation.amountController,
            labelText: 'Allocated Amount',
            fieldName: 'Allocated Amount',
          ),
        ],
      ),
    );
  }

  Future<void> _reloadLinkableTaskItems() async {
    final jobId = _selectedJob.jobId;
    if (jobId == null) {
      _linkableTaskItems = [];
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final candidates = await DaoTaskItem().getPurchasedItemsForReceiptLink(
      jobId: jobId,
      supplierId: _supplierId,
    );
    final linked = currentEntity == null
        ? <TaskItem>[]
        : await DaoReceipt().getLinkedTaskItems(currentEntity!.id);
    final byId = <int, TaskItem>{
      for (final item in candidates) item.id: item,
      for (final item in linked) item.id: item,
    };
    _linkableTaskItems = byId.values.toList()
      ..sort((lhs, rhs) => rhs.modifiedDate.compareTo(lhs.modifiedDate));
    if (mounted) {
      setState(() {});
    }
  }

  String _formatTaskItemCost(TaskItem item) {
    final unitCost =
        item.actualMaterialUnitCost ?? item.estimatedMaterialUnitCost;
    final quantity =
        item.actualMaterialQuantity ?? item.estimatedMaterialQuantity;
    if (unitCost == null || quantity == null) {
      return item.itemType.label;
    }

    final total = unitCost.multiplyByFixed(quantity);
    return '${item.itemType.label} - $quantity x $unitCost = $total';
  }

  void _recalculate() {
    if (_isCalculating) {
      return;
    }
    _isCalculating = true;

    final excl = _totalExclCtrl.money;
    final tax = _taxCtrl.money;
    final incl = _totalInclCtrl.money;

    final provided = [
      _taxHasUserValue,
      _taxExHasUserValue,
      _taxIncHasUserValue,
    ].where((m) => m).length;

    /// We only do the calc for a field if:
    /// * it is blank
    /// * the other two fields have a value.
    /// * the field isn't currently focused.
    if (provided == 2) {
      if (!_taxIncHasUserValue && !_taxIncFocus.hasFocus) {
        _totalInclCtrl.money = excl! + tax!;
      } else if (!_taxHasUserValue && !_taxFocus.hasFocus) {
        _taxCtrl.money = incl! - excl!;
      } else if (!_taxExHasUserValue && !_taxExFocus.hasFocus) {
        _totalExclCtrl.money = incl! - tax!;
      }
    }

    _isCalculating = false;
  }

  Future<bool> _validateTotals() async {
    final totalExcludingTax = MoneyEx.tryParse(_totalExclCtrl.text);
    final tax = MoneyEx.tryParse(_taxCtrl.text);
    final totalIncludingTax = MoneyEx.tryParse(_totalInclCtrl.text);

    if (totalExcludingTax + tax != totalIncludingTax) {
      HMBToast.error(
        'The Total Including Tax should be ${totalExcludingTax + tax}',
      );
      return false;
    }
    final allocationTotal = _jobAllocations.fold(
      MoneyEx.zero,
      (total, allocation) => total + allocation.amount,
    );
    if (_jobAllocations.any((allocation) => allocation.jobId == null)) {
      HMBToast.error('Each receipt allocation must have a job.');
      return false;
    }
    if (_jobAllocations.any((allocation) => !allocation.amount.isPositive)) {
      HMBToast.error('Each receipt allocation must be greater than zero.');
      return false;
    }
    if (allocationTotal != totalExcludingTax) {
      HMBToast.error('Job allocations should add up to $totalExcludingTax.');
      return false;
    }
    return true;
  }
}

class _ReceiptJobAllocationEditor {
  final selectedJob = SelectedJob();
  final HMBMoneyEditingController amountController;

  _ReceiptJobAllocationEditor({int? jobId, Money? amount})
    : amountController = HMBMoneyEditingController(money: amount) {
    selectedJob.jobId = jobId;
  }

  int? get jobId => selectedJob.jobId;

  set jobId(int? value) => selectedJob.jobId = value;

  Money get amount => amountController.money ?? MoneyEx.zero;

  set amount(Money value) => amountController.money = value;
}
