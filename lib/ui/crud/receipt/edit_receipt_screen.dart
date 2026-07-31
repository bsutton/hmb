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

import '../../../api/chat_gpt/receipt_api_client.dart';
import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../entity/helpers/charge_mode.dart';
import '../../../entity/receipt_expense_category.dart';
import '../../../util/dart/app_settings.dart';
import '../../../util/dart/measurement_type.dart';
import '../../../util/dart/money_ex.dart';
import '../../../util/dart/photo_meta.dart';
import '../../../util/dart/units.dart';
import '../../task_items/material_price_editor.dart';
import '../../test_keys.dart';
import '../../widgets/fields/fields.g.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/select/hmb_select_job.dart';
import '../../widgets/select/hmb_select_supplier.dart';
import '../../widgets/widgets.g.dart' hide StatefulBuilder;
import '../base_full_screen/edit_entity_screen.dart';
import '../task/photo_crud.dart';
import 'receipt_task_item_matcher.dart';

enum _ReceiptTaxMode {
  taxFree('Tax free'),
  defaultRate('Default rate'),
  customRate('Custom rate'),
  directEntry('Direct entry');

  const _ReceiptTaxMode(this.label);

  final String label;
}

class ReceiptEditScreen extends StatefulWidget {
  final Receipt? receipt;

  const ReceiptEditScreen({super.key, this.receipt});

  @override
  State<ReceiptEditScreen> createState() => _ReceiptEditScreenState();
}

class _ReceiptEditScreenState extends DeferredState<ReceiptEditScreen>
    implements EntityState<Receipt> {
  static const _autoMatchMinimumScore = 120;
  static const _autoMatchMinimumGap = 20;
  static const _stepPadding = EdgeInsets.symmetric(horizontal: 4, vertical: 12);
  static const _lineItemPadding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 10,
  );

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
  final _legacyLinkedTaskItemIds = <int>{};
  final _matchedTaskItemUpdates = <int, TaskItem>{};
  var _linkableTaskItems = <TaskItem>[];
  final _jobAllocations = <_ReceiptJobAllocationEditor>[];
  final _lineItems = <_ReceiptLineItemEditor>[];
  Task? _lastCreatedLineTask;

  var _isCalculating = false;
  var _isExtractingLines = false;

  var _taxLabel = 'Tax';
  var _taxRateBasisPoints = 1000;
  var _taxMode = _ReceiptTaxMode.defaultRate;
  final _customTaxRateController = TextEditingController();

  final _taxExFocus = FocusNode();
  final _taxFocus = FocusNode();
  final _taxIncFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  @override
  Future<void> asyncInitState() async {
    currentEntity = widget.receipt;
    _date = currentEntity?.receiptDate ?? DateTime.now();
    _selectedJob.jobId = currentEntity?.jobId;
    _supplierId = currentEntity?.supplierId;
    selectedSupplier.selected = _supplierId;
    await _loadTaxSettings();

    // Tax Exc
    _totalExclCtrl = HMBMoneyEditingController(
      money: currentEntity?.totalExcludingTax,
    );
    _totalExclCtrl.addListener(() {
      if (!_isCalculating) {
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
    _taxCtrl.addListener(() {
      if (!_isCalculating) {
        _recalculate();
      }
    });

    /// Tax inc
    _totalInclCtrl = HMBMoneyEditingController(
      money: currentEntity?.totalIncludingTax,
    );
    _totalInclCtrl.addListener(() {
      if (!_isCalculating) {
        _recalculate();
      }
    });

    _photoCtrl = PhotoController<Receipt>(
      parent: currentEntity,
      parentType: ParentType.receipt,
    );
    if (currentEntity != null) {
      final linkedIds = await DaoReceipt().getLinkedTaskItemIds(
        currentEntity!.id,
      );
      _linkedTaskItemIds.addAll(linkedIds);
      _lineItems.addAll(
        (await DaoReceiptLineItem().getByReceiptId(
          currentEntity!.id,
        )).map(_ReceiptLineItemEditor.fromEntity),
      );
      final matchedIds = {
        for (final line in _lineItems)
          if (line.matchedTaskItemId != null) line.matchedTaskItemId!,
      };
      _legacyLinkedTaskItemIds.addAll(
        linkedIds.where((id) => !matchedIds.contains(id)),
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
  void dispose() {
    _totalExclCtrl.dispose();
    _taxCtrl.dispose();
    _totalInclCtrl.dispose();
    _taxExFocus.dispose();
    _taxFocus.dispose();
    _taxIncFocus.dispose();
    _customTaxRateController.dispose();
    _photoCtrl.dispose();
    for (final allocation in _jobAllocations) {
      allocation.dispose();
    }
    for (final line in _lineItems) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (_) => Scaffold(
      appBar: AppBar(
        title: Text(currentEntity == null ? 'Add Receipt' : 'Edit Receipt'),
      ),
      body: Form(
        key: _formKey,
        child: Wizard(
          bodyStart: 24,
          initialSteps: [
            _ReceiptCaptureStep(this),
            _ReceiptLinesStep(this),
            _ReceiptTotalsStep(this),
            _ReceiptAllocationStep(this),
            _ReceiptTaskLinksStep(this),
          ],
          onFinished: _onWizardFinished,
        ),
      ),
    ),
  );

  Future<void> _onWizardFinished(WizardCompletionReason reason) async {
    switch (reason) {
      case WizardCompletionReason.completed:
        if (await _saveReceipt() && mounted) {
          Navigator.of(context).pop(currentEntity);
        }
      case WizardCompletionReason.cancelled:
      case WizardCompletionReason.backedOut:
        if (mounted) {
          Navigator.of(context).pop();
        }
    }
  }

  Future<bool> _saveReceipt() async {
    if (!(_formKey.currentState?.validate() ?? true)) {
      return false;
    }
    if (!_validateReceiptDetails()) {
      return false;
    }
    if (!await _validateTotals()) {
      return false;
    }
    if (!await _prepareMatchedTaskItemUpdates()) {
      return false;
    }

    try {
      final receiptDao = DaoReceipt();
      late Receipt savedReceipt;
      await receiptDao.withTransaction((transaction) async {
        if (currentEntity == null) {
          final newEntity = await forInsert();
          await receiptDao.insert(newEntity, transaction);
          savedReceipt = newEntity;
        } else {
          final updatedEntity = await forUpdate(currentEntity!);
          await receiptDao.update(updatedEntity, transaction);
          savedReceipt = updatedEntity;
        }

        _syncLinkedTaskItemIdsFromLines();
        for (final item in _matchedTaskItemUpdates.values) {
          await DaoTaskItem().update(item, transaction);
        }
        await receiptDao.replaceTaskItemLinks(
          savedReceipt.id,
          _linkedTaskItemIds,
          transaction,
        );
        await DaoReceiptLineItem().replaceForReceipt(
          savedReceipt.id,
          _lineItems.map((line) => line.toEntity(receiptId: savedReceipt.id)),
          transaction,
        );
        await receiptDao.replaceJobAllocations(
          savedReceipt.id,
          _jobAllocations.map(
            (allocation) => ReceiptJobAllocation.forInsert(
              receiptId: savedReceipt.id,
              jobId: allocation.jobId!,
              amount: allocation.amount,
            ),
          ),
          transaction,
        );
      });
      currentEntity = savedReceipt;
      await postSave(currentEntity!);
      if (mounted) {
        setState(() {});
      }
      return true;
    } catch (error) {
      HMBToast.error(error.toString());
      return false;
    }
  }

  bool _validateCurrentWizardStep() =>
      _formKey.currentState?.validate() ?? true;

  bool _validateReceiptDetails() {
    if (_supplierId == null) {
      HMBToast.error('Select a supplier for this receipt.');
      return false;
    }
    return true;
  }

  Widget _buildReceiptCapture() => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _buildStepIntro('Capture the receipt source details.'),
      // Date
      HMBDateTimeField(
        key: TestKeys.receiptDateField,
        mode: HMBDateTimeFieldMode.dateOnly,
        label: 'Receipt Date',
        initialDateTime: _date,
        onChanged: (v) => _date = v,
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

      // Photos
      PhotoCrud<Receipt>(
        key: ValueKey(currentEntity?.id),
        parentName: 'Receipt',
        parentType: ParentType.receipt,
        controller: _photoCtrl,
        allowPendingPhotos: true,
        showCommentField: false,
      ),
    ],
  );

  Widget _buildReceiptTotals() {
    final lineExTaxTotal = _lineItems.fold(
      MoneyEx.zero,
      (total, line) => total + line.lineTotalExTax,
    );
    final lineTaxTotal = _lineItems.fold(
      MoneyEx.zero,
      (total, line) => total + (line.taxAmountController.money ?? MoneyEx.zero),
    );
    final lineIncTaxTotal = _lineItems.fold(
      MoneyEx.zero,
      (total, line) => total + line.lineTotalIncTax,
    );

    return HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepIntro('Review the receipt totals.'),
        if (_lineItems.isNotEmpty) ...[
          Text(
            'Line totals: $lineExTaxTotal excl. tax, $lineTaxTotal tax, '
            '$lineIncTaxTotal incl. tax.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: HMBButton.withIcon(
              label: 'Use Line Totals',
              hint: 'Copy the receipt line totals into the receipt totals.',
              icon: const Icon(Icons.functions),
              onPressed: () {
                setState(() {
                  _isCalculating = true;
                  _totalExclCtrl.money = lineExTaxTotal;
                  _taxCtrl.money = lineTaxTotal;
                  _totalInclCtrl.money = lineIncTaxTotal;
                  _isCalculating = false;
                });
                _applyTaxMode();
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        // MONEY FIELDS: dollars entry
        HMBMoneyField(
          fieldKey: TestKeys.receiptTotalIncludingTaxField,
          controller: _totalInclCtrl,
          labelText: 'Total Incl. Tax',
          fieldName: 'Total Including Tax',
          focusNode: _taxIncFocus,
        ),
        HMBDroplist<_ReceiptTaxMode>(
          title: 'Tax Treatment',
          selectedItem: () async => _taxMode,
          items: (_) async => _ReceiptTaxMode.values,
          onChanged: (mode) {
            _taxMode = mode ?? _ReceiptTaxMode.defaultRate;
            _applyTaxMode();
          },
          format: _formatTaxMode,
          showSearch: false,
        ),
        if (_taxMode == _ReceiptTaxMode.customRate) ...[
          const SizedBox(height: 8),
          HMBTextField(
            controller: _customTaxRateController,
            labelText: 'Custom Tax Rate (%)',
            keyboardType: TextInputType.number,
            onChanged: (_) => _applyTaxMode(),
          ),
        ],
        const SizedBox(height: 8),
        HMBMoneyField(
          fieldKey: TestKeys.receiptTaxField,
          controller: _taxCtrl,
          labelText: _taxLabel,
          fieldName: _taxLabel,
          focusNode: _taxFocus,
          enabled: _taxMode == _ReceiptTaxMode.directEntry,
          nonZero: false,
        ),
        HMBMoneyField(
          fieldKey: TestKeys.receiptTotalExcludingTaxField,
          controller: _totalExclCtrl,
          labelText: 'Total Excl. Tax',
          fieldName: 'Total Excluding Tax',
          focusNode: _taxExFocus,
          enabled: false,
        ),
      ],
    );
  }

  Future<void> _loadTaxSettings() async {
    final label = (await AppSettings.getTaxLabel()).trim();
    _taxLabel = label.isEmpty ? 'GST' : label;

    final rateText = await AppSettings.getTaxRatePercentText();
    final ratePercent = double.tryParse(rateText.trim().replaceAll('%', ''));
    if (ratePercent != null && ratePercent > 0) {
      _taxRateBasisPoints = (ratePercent * 100).round();
    }
    _customTaxRateController.text = _formatTaxRate(_taxRateBasisPoints);
  }

  String _formatTaxMode(_ReceiptTaxMode mode) => switch (mode) {
    _ReceiptTaxMode.taxFree => 'Tax free',
    _ReceiptTaxMode.defaultRate =>
      '$_taxLabel ${_formatTaxRate(_taxRateBasisPoints)}%',
    _ReceiptTaxMode.customRate => 'Custom rate',
    _ReceiptTaxMode.directEntry => 'Direct entry',
  };

  String _formatTaxRate(int basisPoints) {
    final rate = basisPoints / 100;
    return rate == rate.roundToDouble() ? rate.toInt().toString() : '$rate';
  }

  int _customTaxRateBasisPoints() {
    final ratePercent = double.tryParse(
      _customTaxRateController.text.trim().replaceAll('%', ''),
    );
    if (ratePercent == null || ratePercent < 0) {
      return 0;
    }
    return (ratePercent * 100).round();
  }

  void _applyTaxMode() {
    final totalIncludingTax = _totalInclCtrl.money ?? MoneyEx.zero;
    if (_taxMode == _ReceiptTaxMode.directEntry) {
      _calculateExclusiveFromDirectTax();
      return;
    }

    final rateBasisPoints = switch (_taxMode) {
      _ReceiptTaxMode.taxFree => 0,
      _ReceiptTaxMode.defaultRate => _taxRateBasisPoints,
      _ReceiptTaxMode.customRate => _customTaxRateBasisPoints(),
      _ReceiptTaxMode.directEntry => 0,
    };
    final tax = _calculateTaxFromInclusiveTotal(
      totalIncludingTax,
      rateBasisPoints,
    );
    _setCalculatedTotals(totalIncludingTax: totalIncludingTax, tax: tax);
  }

  Money _calculateTaxFromInclusiveTotal(
    Money totalIncludingTax,
    int rateBasisPoints,
  ) {
    if (totalIncludingTax.isZero || rateBasisPoints == 0) {
      return MoneyEx.zero;
    }

    final totalMinorUnits = totalIncludingTax.minorUnits.toInt();
    final sign = totalMinorUnits.isNegative ? -1 : 1;
    final absoluteTotal = totalMinorUnits.abs();
    final divisor = 10000 + rateBasisPoints;
    final taxMinorUnits =
        sign * ((absoluteTotal * rateBasisPoints + divisor ~/ 2) ~/ divisor);
    return MoneyEx.fromInt(taxMinorUnits);
  }

  void _calculateExclusiveFromDirectTax() {
    final totalIncludingTax = _totalInclCtrl.money ?? MoneyEx.zero;
    final tax = _taxCtrl.money ?? MoneyEx.zero;
    _setCalculatedTotals(
      totalIncludingTax: totalIncludingTax,
      tax: tax,
      updateTax: false,
    );
  }

  void _setCalculatedTotals({
    required Money totalIncludingTax,
    required Money tax,
    bool updateTax = true,
  }) {
    setState(() {
      _isCalculating = true;
      if (updateTax) {
        _taxCtrl.money = tax;
      }
      _totalExclCtrl.money = totalIncludingTax - tax;
      _isCalculating = false;
    });
  }

  void _applyLineTaxMode(_ReceiptLineItemEditor line) {
    if (_isCalculating) {
      return;
    }
    final totalIncludingTax = line.lineTotalIncTax;
    if (line.taxMode == _ReceiptTaxMode.directEntry) {
      _setLineCalculatedTotals(
        line: line,
        totalIncludingTax: totalIncludingTax,
        tax: line.taxAmountController.money ?? MoneyEx.zero,
        updateTax: false,
      );
      return;
    }

    final rateBasisPoints = switch (line.taxMode) {
      _ReceiptTaxMode.taxFree => 0,
      _ReceiptTaxMode.defaultRate => _taxRateBasisPoints,
      _ReceiptTaxMode.customRate => _lineCustomTaxRateBasisPoints(line),
      _ReceiptTaxMode.directEntry => 0,
    };
    _setLineCalculatedTotals(
      line: line,
      totalIncludingTax: totalIncludingTax,
      tax: _calculateTaxFromInclusiveTotal(totalIncludingTax, rateBasisPoints),
    );
  }

  int _lineCustomTaxRateBasisPoints(_ReceiptLineItemEditor line) {
    final ratePercent = double.tryParse(
      line.customTaxRateController.text.trim().replaceAll('%', ''),
    );
    if (ratePercent == null || ratePercent < 0) {
      return 0;
    }
    return (ratePercent * 100).round();
  }

  void _setLineCalculatedTotals({
    required _ReceiptLineItemEditor line,
    required Money totalIncludingTax,
    required Money tax,
    bool updateTax = true,
  }) {
    setState(() {
      _isCalculating = true;
      if (updateTax) {
        line.taxAmountController.money = tax;
      }
      line.lineTotalExTaxController.money = totalIncludingTax - tax;
      _isCalculating = false;
    });
  }

  @override
  Future<Receipt> forUpdate(Receipt receipt) async => receipt.copyWith(
    jobId: _selectedJob.jobId,
    clearJob: _selectedJob.jobId == null,
    supplierId: _supplierId,
    totalExcludingTax: MoneyEx.tryParse(_totalExclCtrl.text),
    tax: MoneyEx.tryParse(_taxCtrl.text),
    totalIncludingTax: MoneyEx.tryParse(_totalInclCtrl.text),
  );

  @override
  Future<Receipt> forInsert() async => Receipt.forInsert(
    receiptDate: _date,
    jobId: _selectedJob.jobId,
    supplierId: _supplierId!,
    totalExcludingTax: MoneyEx.tryParse(_totalExclCtrl.text),
    tax: MoneyEx.tryParse(_taxCtrl.text),
    totalIncludingTax: MoneyEx.tryParse(_totalInclCtrl.text),
  );

  @override
  Future<void> postSave(_) async {
    _photoCtrl.parent = currentEntity;
    if (currentEntity != null) {
      await _photoCtrl.savePendingPhotos();
      await _photoCtrl.save();
    }
    await _photoCtrl.load();
    await _reloadLinkableTaskItems();
    setState(() {});
  }

  Widget _buildStepIntro(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );

  Widget _buildLineItems() {
    final lineTotal = _lineItems.fold(
      MoneyEx.zero,
      (total, line) => total + line.lineTotalExTax,
    );
    final receiptTotal = _totalExclCtrl.money ?? MoneyEx.zero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepIntro(
          'Extract lines from the photo, or enter them manually. Review before '
          'saving.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            HMBButton.withIcon(
              label: _isExtractingLines ? 'Extracting...' : 'Extract Lines',
              hint: 'Use the ChatGPT integration to read receipt lines.',
              icon: _isExtractingLines
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              enabled: !_isExtractingLines,
              onPressed: _extractLineItems,
            ),
            HMBButton.withIcon(
              label: 'Add Line',
              hint: 'Add a receipt line manually.',
              icon: const Icon(Icons.add),
              onPressed: _addManualLine,
            ),
          ],
        ),
        if (_lineItems.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No receipt lines have been entered.'),
          )
        else ...[
          const SizedBox(height: 8),
          for (var i = 0; i < _lineItems.length; i++) _buildLineItemRow(i),
          Text(
            lineTotal == receiptTotal
                ? 'Line total matches receipt total: $lineTotal'
                : 'Line total $lineTotal does not match receipt total '
                      '$receiptTotal.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildLineItemRow(int index) {
    final line = _lineItems[index];
    return Card(
      child: Padding(
        padding: _lineItemPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: HMBTextField(
                    controller: line.descriptionController,
                    labelText: 'Description',
                    required: true,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove receipt line',
                  onPressed: () {
                    setState(() {
                      _lineItems.removeAt(index).dispose();
                    });
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            HMBTextField(
              controller: line.quantityController,
              labelText: 'Quantity',
              required: true,
            ),
            const SizedBox(height: 10),
            HMBMoneyField(
              controller: line.unitPriceController,
              labelText: 'Unit Price',
              fieldName: 'Unit Price',
              nonZero: false,
            ),
            const SizedBox(height: 10),
            HMBMoneyField(
              controller: line.lineTotalIncTaxController,
              labelText: 'Line Total Incl. Tax',
              fieldName: 'Line Total Including Tax',
              nonZero: false,
              onChanged: (_) => _applyLineTaxMode(line),
            ),
            const SizedBox(height: 10),
            HMBDroplist<_ReceiptTaxMode>(
              title: 'Line Tax Treatment',
              selectedItem: () async => line.taxMode,
              items: (_) async => _ReceiptTaxMode.values,
              onChanged: (mode) {
                line.taxMode = mode ?? _taxMode;
                _applyLineTaxMode(line);
              },
              format: _formatTaxMode,
              showSearch: false,
            ),
            if (line.taxMode == _ReceiptTaxMode.customRate) ...[
              const SizedBox(height: 10),
              HMBTextField(
                controller: line.customTaxRateController,
                labelText: 'Line Custom Tax Rate (%)',
                keyboardType: TextInputType.number,
                onChanged: (_) => _applyLineTaxMode(line),
              ),
            ],
            const SizedBox(height: 10),
            HMBMoneyField(
              controller: line.taxAmountController,
              labelText: _taxLabel,
              fieldName: _taxLabel,
              nonZero: false,
              enabled: line.taxMode == _ReceiptTaxMode.directEntry,
              onChanged: (_) => _applyLineTaxMode(line),
            ),
            const SizedBox(height: 10),
            HMBMoneyField(
              controller: line.lineTotalExTaxController,
              labelText: 'Line Total Excl. Tax',
              fieldName: 'Line Total Excluding Tax',
              nonZero: false,
              enabled: false,
            ),
            const SizedBox(height: 10),
            HMBDroplist<ReceiptExpenseCategory>(
              title: 'Expense Account',
              selectedItem: () async => line.expenseCategory,
              items: (_) async => ReceiptExpenseCategory.values,
              onChanged: (category) {
                setState(() {
                  line.expenseCategory =
                      category ?? ReceiptExpenseCategory.materials;
                });
              },
              format: (category) => category.label,
              showSearch: false,
            ),
            const SizedBox(height: 10),
            HMBDroplist<TaskItem>(
              title: 'Matched Task Item',
              required: false,
              selectedItem: () async => line.matchedTaskItemId == null
                  ? null
                  : _firstOrNull(
                      await DaoTaskItem().getByIds([line.matchedTaskItemId!]),
                    ),
              items: (_) async => _rankedTaskItemsForLine(line),
              onAdd: () => _createTaskItemForLine(line),
              onChanged: (item) => _setLineMatch(line, item),
              format: _formatTaskItemMatch,
            ),
            if (line.matchedTaskItemId != null && !line.matchReviewed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome),
                title: const Text('Suggested match'),
                subtitle: const Text(
                  'Review this suggestion before saving the receipt.',
                ),
                trailing: HMBButton.small(
                  onPressed: () => setState(() {
                    line.matchReviewed = true;
                  }),
                  label: 'Confirm',
                  hint: 'Confirm this suggested task item match',
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: HMBButton.withIcon(
                label: 'Create Task Item',
                hint: 'Create a task item for this receipt line.',
                icon: const Icon(Icons.add_task),
                onPressed: () => _createTaskItemForLine(line),
              ),
            ),
            if (line.source != 'manual' || line.confidence > 0)
              Text(
                '${line.source} confidence ${line.confidence}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _extractLineItems() async {
    final photos = await _photoCtrl.photos;
    if (photos.isEmpty) {
      HMBToast.error('Add a receipt photo before extracting lines.');
      return;
    }

    setState(() => _isExtractingLines = true);
    try {
      final photo = photos.last;
      final path = await PhotoMeta.getAbsolutePath(photo.photo);
      final result = await ReceiptApiClient().extractData(path);
      if (result == null) {
        HMBToast.error(
          'Add your OpenAI API key in Settings | Integrations | ChatGPT.',
        );
        return;
      }
      _applyExtraction(result);
      final matchedCount = await _matchExtractedLinesToTaskItems();
      final matchSuffix = matchedCount == 0
          ? ''
          : ' Matched $matchedCount to task items.';
      HMBToast.info(
        'Extracted ${result.lines.length} receipt lines.$matchSuffix',
      );
    } catch (e) {
      HMBToast.error('Receipt extraction failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isExtractingLines = false);
      }
    }
  }

  void _applyExtraction(ReceiptExtractionResult result) {
    for (final line in _lineItems) {
      line.dispose();
    }
    final totals = _balancedExtractionTotals(result);
    setState(() {
      if (result.receiptDate != null) {
        _date = result.receiptDate!;
      }
      if (totals.excluding.isPositive) {
        _totalExclCtrl.money = totals.excluding;
      }
      if (totals.tax.isPositive) {
        _taxCtrl.money = totals.tax;
      }
      if (totals.including.isPositive) {
        _totalInclCtrl.money = totals.including;
      }
      _lineItems
        ..clear()
        ..addAll(result.lines.map(_ReceiptLineItemEditor.fromExtraction));
      if (_jobAllocations.length == 1 && _selectedJob.jobId != null) {
        _jobAllocations.single.amount = _totalExclCtrl.money ?? MoneyEx.zero;
      }
    });
    for (final line in _lineItems) {
      if (line.taxAmountController.money == MoneyEx.zero) {
        line
          ..taxMode = _taxMode
          ..customTaxRateController.text = _formatTaxRate(_taxRateBasisPoints);
        _applyLineTaxMode(line);
      }
    }
    if (result.warnings.isNotEmpty) {
      HMBToast.info(result.warnings.first);
    }
  }

  _ReceiptTotals _balancedExtractionTotals(ReceiptExtractionResult result) {
    var excluding = MoneyEx.fromInt(result.totalExcludingTax);
    final tax = MoneyEx.fromInt(result.tax);
    var including = MoneyEx.fromInt(result.totalIncludingTax);

    if (including.isPositive && tax.isPositive) {
      excluding = including - tax;
    } else if (excluding.isPositive && tax.isPositive) {
      including = excluding + tax;
    }

    return _ReceiptTotals(excluding: excluding, tax: tax, including: including);
  }

  void _addManualLine() {
    setState(() {
      _lineItems.add(
        _ReceiptLineItemEditor(
          description: '',
          quantity: 1,
          unitPrice: MoneyEx.zero,
          lineTotalExTax: MoneyEx.zero,
          taxAmount: MoneyEx.zero,
          lineTotalIncTax: MoneyEx.zero,
          matchedTaskItemId: null,
          expenseCategory: ReceiptExpenseCategory.materials,
          confidence: 100,
          source: 'manual',
        ),
      );
    });
  }

  Future<int> _matchExtractedLinesToTaskItems() async {
    await _reloadLinkableTaskItems();
    final alreadyUsedTaskItemIds = {
      for (final line in _lineItems)
        if (line.matchedTaskItemId != null) line.matchedTaskItemId!,
    };
    var matchedCount = 0;

    for (final line in _lineItems.where((line) => line.source != 'manual')) {
      if (line.matchedTaskItemId != null) {
        continue;
      }

      final input = line.matchInput(
        receiptDate: _date,
        supplierId: _supplierId,
      );
      final scored =
          [
            for (final item in _linkableTaskItems)
              if (item.isReturn == line.isReturn &&
                  !alreadyUsedTaskItemIds.contains(item.id))
                _ScoredReceiptTaskItem(
                  item: item,
                  score: ReceiptTaskItemMatcher.scoreLine(item, input),
                ),
          ]..sort((lhs, rhs) {
            final byScore = rhs.score.compareTo(lhs.score);
            if (byScore != 0) {
              return byScore;
            }
            return rhs.item.modifiedDate.compareTo(lhs.item.modifiedDate);
          });

      if (scored.isEmpty) {
        continue;
      }

      final best = scored.first;
      final nextBestScore = scored.length > 1 ? scored[1].score : 0;
      if (best.score < _autoMatchMinimumScore ||
          best.score - nextBestScore < _autoMatchMinimumGap) {
        continue;
      }

      line
        ..matchedTaskItemId = best.item.id
        ..matchReviewed = false;
      alreadyUsedTaskItemIds.add(best.item.id);
      _linkedTaskItemIds.add(best.item.id);
      matchedCount++;
    }

    if (matchedCount > 0 && mounted) {
      setState(() {});
    }
    return matchedCount;
  }

  Widget _buildTaskItemLinks() {
    final matchedIds = {
      for (final line in _lineItems)
        if (line.matchedTaskItemId != null) line.matchedTaskItemId!,
    };
    final legacyIds = _linkedTaskItemIds.difference(matchedIds);
    final itemsById = {for (final item in _linkableTaskItems) item.id: item};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIntro(
          'Task Item links are derived from the receipt-line matches. '
          'Return to Receipt Lines to change them.',
        ),
        if (matchedIds.isEmpty)
          const Text('No receipt lines are matched to Task Items.')
        else
          for (final id in matchedIds)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: Text(itemsById[id]?.description ?? 'Task Item #$id'),
              subtitle: itemsById[id] == null
                  ? null
                  : Text(_formatTaskItemCost(itemsById[id]!)),
            ),
        if (legacyIds.isNotEmpty) ...[
          const Divider(),
          const Text('Legacy receipt links retained for audit:'),
          for (final id in legacyIds)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: Text(itemsById[id]?.description ?? 'Task Item #$id'),
            ),
        ],
      ],
    );
  }

  Widget _buildJobAllocations() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildStepIntro(
        'Classify the receipt as overhead, or allocate it to one or more jobs.',
      ),
      HMBSelectJob(
        key: TestKeys.receiptPrimaryJobSelector,
        title: 'Primary Job',
        selectedJob: _selectedJob,
        onSelected: (job) {
          setState(() {
            _selectedJob.jobId = job?.id;
            if (job == null) {
              _jobAllocations.clear();
            } else if (_jobAllocations.length <= 1) {
              _jobAllocations
                ..clear()
                ..add(
                  _ReceiptJobAllocationEditor(
                    jobId: job.id,
                    amount: _totalExclCtrl.money ?? MoneyEx.zero,
                  ),
                );
            }
          });
          unawaited(_reloadLinkableTaskItems());
        },
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < _jobAllocations.length; i++)
        _buildJobAllocationRow(i),
      HMBButton.withIcon(
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
    final since = _date.subtract(const Duration(days: 45));
    final candidates = await DaoTaskItem().getPurchasedItemsForReceiptLink(
      jobId: jobId,
      supplierId: _supplierId,
      since: since,
    );
    final returnedCandidates = await DaoTaskItem()
        .getReturnedItemsForReceiptLink(
          jobId: jobId,
          supplierId: _supplierId,
          since: since,
        );
    final linked = currentEntity == null
        ? <TaskItem>[]
        : await DaoReceipt().getLinkedTaskItems(currentEntity!.id);
    final byId = <int, TaskItem>{
      for (final item in candidates) item.id: item,
      for (final item in returnedCandidates) item.id: item,
      for (final item in linked) item.id: item,
    };
    _linkableTaskItems = _rankedTaskItemsForReceipt(byId.values);
    if (mounted) {
      setState(() {});
    }
  }

  List<TaskItem> _rankedTaskItemsForLine(_ReceiptLineItemEditor line) =>
      ReceiptTaskItemMatcher.sortForLine(
        _linkableTaskItems.where((item) => item.isReturn == line.isReturn),
        line.matchInput(receiptDate: _date, supplierId: _supplierId),
      );

  List<TaskItem> _rankedTaskItemsForReceipt([Iterable<TaskItem>? items]) =>
      ReceiptTaskItemMatcher.sortForReceipt(
        items ?? _linkableTaskItems,
        _lineItems.map(
          (line) =>
              line.matchInput(receiptDate: _date, supplierId: _supplierId),
        ),
        _date,
      );

  void _setLineMatch(_ReceiptLineItemEditor line, TaskItem? item) {
    if (item != null &&
        _lineItems.any(
          (other) =>
              !identical(other, line) && other.matchedTaskItemId == item.id,
        )) {
      HMBToast.error('That Task Item is already matched to another line.');
      return;
    }
    setState(() {
      line
        ..matchedTaskItemId = item?.id
        ..matchReviewed = true;
      if (item != null) {
        _linkedTaskItemIds.add(item.id);
      }
      _syncLinkedTaskItemIdsFromLines();
    });
  }

  String _formatTaskItemCost(TaskItem item) {
    final price = item.actualPrice ?? item.estimatedPrice;
    if (price == null) {
      return item.itemType.label;
    }

    final unitLabel = price.isPackagePrice ? 'packages' : 'items';
    return '${item.itemType.label} - ${price.quantity} $unitLabel x '
        '${price.unitCost} = ${price.totalCost}';
  }

  String _formatTaskItemMatch(TaskItem item) =>
      '${item.description} - ${_formatTaskItemCost(item)}';

  Future<void> _createTaskItemForLine(_ReceiptLineItemEditor line) async {
    final selectedJob = SelectedJob()..jobId = _selectedJob.jobId;
    var selectedTask = _lastCreatedLineTask?.jobId == _selectedJob.jobId
        ? _lastCreatedLineTask
        : null;
    var selectedItemType = _itemTypeForExpenseCategory(line.expenseCategory);
    final descriptionController = TextEditingController(text: line.description);
    final priceController = MaterialPriceEditingController(
      price: MaterialPrice.items(
        quantity: _parsePositiveFixed(line.quantity.toString()),
        unitCost: _unitCostForTaskItem(line),
      ),
    );
    final formKey = GlobalKey<FormState>();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Create Task Item'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: HMBColumn(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HMBSelectJob(
                      selectedJob: selectedJob,
                      required: true,
                      onSelected: (job) {
                        setDialogState(() {
                          selectedJob.jobId = job?.id;
                          selectedTask = null;
                        });
                      },
                    ),
                    if (selectedJob.jobId != null)
                      HMBDroplist<Task>(
                        title: 'Task',
                        selectedItem: () async => selectedTask,
                        items: (_) =>
                            DaoTask().getTasksByJob(selectedJob.jobId!),
                        format: (task) => task.name,
                        onChanged: (task) {
                          setDialogState(() {
                            selectedTask = task;
                          });
                        },
                      ),
                    HMBDroplist<TaskItemType>(
                      title: 'Item Type',
                      selectedItem: () async => selectedItemType,
                      items: (_) async => const [
                        TaskItemType.materialsBuy,
                        TaskItemType.consumablesBuy,
                        TaskItemType.toolsBuy,
                        TaskItemType.toolsHire,
                      ],
                      format: (type) => type.label,
                      onChanged: (type) {
                        setDialogState(() {
                          selectedItemType = type ?? TaskItemType.materialsBuy;
                        });
                      },
                      showSearch: false,
                    ),
                    HMBTextField(
                      controller: descriptionController,
                      labelText: 'Description',
                      required: true,
                    ),
                    MaterialPriceEditor(
                      controller: priceController,
                      title: 'Actual pricing',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              HMBButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                label: 'Cancel',
                hint: "Don't create a task item",
              ),
              HMBButton(
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) {
                    return;
                  }
                  if (selectedTask == null) {
                    HMBToast.error('Select a task for this receipt line.');
                    return;
                  }
                  final price = priceController.value;
                  if (price == null) {
                    return;
                  }
                  final item = await _insertTaskItemFromLine(
                    isReturn: line.isReturn,
                    task: selectedTask!,
                    itemType: selectedItemType,
                    description: descriptionController.text.trim(),
                    price: price,
                    lineTotalExTax: line.lineTotalExTax,
                  );
                  setState(() {
                    _lastCreatedLineTask = selectedTask;
                    line
                      ..matchedTaskItemId = item.id
                      ..matchReviewed = true;
                    _linkedTaskItemIds.add(item.id);
                  });
                  await _reloadLinkableTaskItems();
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                label: 'Create',
                hint: 'Create and match this task item',
              ),
            ],
          ),
        ),
      );
    } finally {
      descriptionController.dispose();
      priceController.dispose();
    }
  }

  Future<TaskItem> _insertTaskItemFromLine({
    required bool isReturn,
    required Task task,
    required TaskItemType itemType,
    required String description,
    required MaterialPrice price,
    required Money lineTotalExTax,
  }) async {
    final exactUnitCost = _absoluteMoney(
      lineTotalExTax,
    ).divideByFixed(price.quantity);
    final exactPrice = price.mode == MaterialPriceEntryMode.packages
        ? MaterialPrice.packages(
            packageCount: price.quantity,
            packageCost: exactUnitCost,
            itemsPerPackage: price.itemsPerPackage!,
          )
        : MaterialPrice.items(
            quantity: price.quantity,
            unitCost: exactUnitCost,
          );
    final defaultMargin = await DaoSystem().getDefaultProfitMargin();
    final item = TaskItem.forInsert(
      taskId: task.id,
      description: description,
      purpose: 'Created from receipt line',
      itemType: itemType,
      estimatedPrice: exactPrice,
      actualPrice: exactPrice,
      chargeMode: ChargeMode.calculated,
      margin: defaultMargin,
      completed: true,
      measurementType: MeasurementType.length,
      dimension1: Fixed.zero,
      dimension2: Fixed.zero,
      dimension3: Fixed.zero,
      units: Units.defaultUnits,
      url: '',
      labourEntryMode: LabourEntryMode.hours,
      supplierId: _supplierId,
      isReturn: isReturn,
    );
    await DaoTaskItem().insert(item);
    return item;
  }

  TaskItemType _itemTypeForExpenseCategory(ReceiptExpenseCategory category) =>
      switch (category) {
        ReceiptExpenseCategory.tools => TaskItemType.toolsBuy,
        ReceiptExpenseCategory.consumables ||
        ReceiptExpenseCategory.fuel ||
        ReceiptExpenseCategory.parking ||
        ReceiptExpenseCategory.vehicle ||
        ReceiptExpenseCategory.office ||
        ReceiptExpenseCategory.insurance ||
        ReceiptExpenseCategory.other => TaskItemType.consumablesBuy,
        ReceiptExpenseCategory.materials ||
        ReceiptExpenseCategory.subcontractor => TaskItemType.materialsBuy,
      };

  Money _unitCostForTaskItem(_ReceiptLineItemEditor line) {
    if (line.unitPrice.isNonZero) {
      return _absoluteMoney(line.unitPrice);
    }
    return _absoluteMoney(
      line.lineTotalExTax,
    ).divideByFixed(_parsePositiveFixed(line.quantity.toString()));
  }

  Fixed _parsePositiveFixed(String value) {
    final parsed = Fixed.tryParse(
      value.trim().replaceFirst('-', ''),
      decimalDigits: 3,
    );
    if (parsed == null || parsed.isZero) {
      return Fixed.one;
    }
    return parsed;
  }

  Money _absoluteMoney(Money money) =>
      MoneyEx.fromInt(money.minorUnits.toInt().abs());

  Future<bool> _prepareMatchedTaskItemUpdates() async {
    _matchedTaskItemUpdates.clear();
    final matchedLines = _lineItems
        .where((line) => line.matchedTaskItemId != null)
        .toList();
    final ids = matchedLines.map((line) => line.matchedTaskItemId!).toList();
    if (ids.toSet().length != ids.length) {
      HMBToast.error('A Task Item can only be matched to one receipt line.');
      return false;
    }
    if (matchedLines.any((line) => !line.matchReviewed)) {
      HMBToast.error('Review each suggested Task Item match before saving.');
      return false;
    }

    final changes = <String>[];
    final billedWarnings = <String>[];
    for (final line in matchedLines) {
      final item = await DaoTaskItem().getById(line.matchedTaskItemId);
      if (item == null) {
        HMBToast.error('A matched Task Item no longer exists.');
        return false;
      }
      if (item.billed || item.invoiceLineId != null) {
        billedWarnings.add(
          '${item.description}: already invoiced; its price will not change.',
        );
        continue;
      }

      final previous = item.actualPrice ?? item.estimatedPrice;
      final proposed = ReceiptTaskItemMatcher.actualPriceForLine(
        item: item,
        lineTotalExTax: line.lineTotalExTax,
        fallbackQuantity: _parsePositiveFixed(line.quantityController.text),
      );

      changes.add(
        '${item.description}: ${previous?.totalCost ?? MoneyEx.zero} '
        '→ ${proposed.totalCost}',
      );
      _matchedTaskItemUpdates[item.id] = item.copyWith(
        completed: true,
        actualPrice: proposed,
      );
    }

    final warnings = <String>[
      ...changes,
      ...billedWarnings,
      if (matchedLines.isEmpty && _selectedJob.jobId != null)
        '''This receipt is linked only to a job. It will not be added to an invoice; match its lines to Task Items to bill them.''',
      if (matchedLines.isEmpty && _selectedJob.jobId == null)
        '''This receipt is linked to neither a Task Item nor a job. It will be saved for bookkeeping but will not be billed.''',
      if (matchedLines.isNotEmpty && _jobAllocations.isNotEmpty)
        '''Job allocations are bookkeeping only. Only matched Task Items can flow through to an invoice.''',
    ];
    if (warnings.isEmpty) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              changes.isEmpty
                  ? 'Receipt billing warning'
                  : 'Apply receipt prices?',
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final warning in warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(warning),
                    ),
                ],
              ),
            ),
            actions: [
              HMBButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                label: 'Cancel',
                hint: "Don't apply the receipt prices",
              ),
              HMBButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                label: 'Continue',
                hint: 'Apply the receipt prices and continue',
              ),
            ],
          ),
        ) ??
        false;
  }

  void _syncLinkedTaskItemIdsFromLines() {
    _linkedTaskItemIds
      ..clear()
      ..addAll(_legacyLinkedTaskItemIds);
    for (final line in _lineItems) {
      final taskItemId = line.matchedTaskItemId;
      if (taskItemId != null) {
        _linkedTaskItemIds.add(taskItemId);
      }
    }
  }

  void _recalculate() {
    if (_isCalculating) {
      return;
    }
    _applyTaxMode();
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
    if (_jobAllocations.isEmpty) {
      return true;
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

class _ReceiptCaptureStep extends WizardStep {
  final _ReceiptEditScreenState state;

  _ReceiptCaptureStep(this.state) : super(title: 'Capture');

  @override
  Future<void> onNext(
    BuildContext context,
    WizardStepTarget intendedStep, {
    required bool userOriginated,
  }) async {
    if (!state._validateCurrentWizardStep() ||
        !state._validateReceiptDetails()) {
      intendedStep.cancel();
      return;
    }
    intendedStep.confirm();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: _ReceiptEditScreenState._stepPadding,
    child: state._buildReceiptCapture(),
  );
}

class _ReceiptLinesStep extends WizardStep {
  final _ReceiptEditScreenState state;

  _ReceiptLinesStep(this.state) : super(title: 'Receipt Lines');

  @override
  Future<void> onNext(
    BuildContext context,
    WizardStepTarget intendedStep, {
    required bool userOriginated,
  }) async {
    if (!state._validateCurrentWizardStep()) {
      intendedStep.cancel();
      return;
    }
    intendedStep.confirm();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: _ReceiptEditScreenState._stepPadding,
    child: state._buildLineItems(),
  );
}

class _ReceiptTotalsStep extends WizardStep {
  final _ReceiptEditScreenState state;

  _ReceiptTotalsStep(this.state) : super(title: 'Totals');

  @override
  Future<void> onNext(
    BuildContext context,
    WizardStepTarget intendedStep, {
    required bool userOriginated,
  }) async {
    if (!state._validateCurrentWizardStep() ||
        !(await state._validateTotals())) {
      intendedStep.cancel();
      return;
    }
    intendedStep.confirm();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: _ReceiptEditScreenState._stepPadding,
    child: state._buildReceiptTotals(),
  );
}

class _ReceiptAllocationStep extends WizardStep {
  final _ReceiptEditScreenState state;

  _ReceiptAllocationStep(this.state) : super(title: 'Job Cost Allocation');

  @override
  Future<void> onNext(
    BuildContext context,
    WizardStepTarget intendedStep, {
    required bool userOriginated,
  }) async {
    if (!state._validateCurrentWizardStep() ||
        !(await state._validateTotals())) {
      intendedStep.cancel();
      return;
    }
    intendedStep.confirm();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: _ReceiptEditScreenState._stepPadding,
    child: state._buildJobAllocations(),
  );
}

class _ReceiptTaskLinksStep extends WizardStep {
  final _ReceiptEditScreenState state;

  _ReceiptTaskLinksStep(this.state) : super(title: 'Task Item Links');

  @override
  Widget build(BuildContext context) => Padding(
    padding: _ReceiptEditScreenState._stepPadding,
    child: state._buildTaskItemLinks(),
  );
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

  void dispose() {
    amountController.dispose();
  }
}

class _ReceiptTotals {
  final Money excluding;
  final Money tax;
  final Money including;

  const _ReceiptTotals({
    required this.excluding,
    required this.tax,
    required this.including,
  });
}

class _ScoredReceiptTaskItem {
  final TaskItem item;
  final int score;

  const _ScoredReceiptTaskItem({required this.item, required this.score});
}

class _ReceiptLineItemEditor {
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final HMBMoneyEditingController unitPriceController;
  final HMBMoneyEditingController lineTotalExTaxController;
  final HMBMoneyEditingController taxAmountController;
  final HMBMoneyEditingController lineTotalIncTaxController;
  final TextEditingController customTaxRateController;
  int? matchedTaskItemId;
  var matchReviewed = true;
  _ReceiptTaxMode taxMode;
  ReceiptExpenseCategory expenseCategory;
  final int confidence;
  final String source;

  _ReceiptLineItemEditor({
    required String description,
    required double quantity,
    required Money unitPrice,
    required Money lineTotalExTax,
    required Money taxAmount,
    required Money lineTotalIncTax,
    required this.matchedTaskItemId,
    required this.expenseCategory,
    required this.confidence,
    required this.source,
    this.taxMode = _ReceiptTaxMode.defaultRate,
    String customTaxRate = '10',
  }) : descriptionController = TextEditingController(text: description),
       quantityController = TextEditingController(text: quantity.toString()),
       unitPriceController = HMBMoneyEditingController(money: unitPrice),
       lineTotalExTaxController = HMBMoneyEditingController(
         money: lineTotalExTax,
       ),
       taxAmountController = HMBMoneyEditingController(money: taxAmount),
       lineTotalIncTaxController = HMBMoneyEditingController(
         money: lineTotalIncTax,
       ),
       customTaxRateController = TextEditingController(text: customTaxRate);

  factory _ReceiptLineItemEditor.fromEntity(ReceiptLineItem item) =>
      _ReceiptLineItemEditor(
        description: item.description,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        lineTotalExTax: item.lineTotalExTax,
        taxAmount: item.taxAmount,
        lineTotalIncTax: item.lineTotalIncTax,
        matchedTaskItemId: item.matchedTaskItemId,
        taxMode: item.taxAmount.isZero
            ? _ReceiptTaxMode.taxFree
            : _ReceiptTaxMode.directEntry,
        expenseCategory: item.expenseCategory,
        confidence: item.confidence,
        source: item.source,
      );

  factory _ReceiptLineItemEditor.fromExtraction(ReceiptLineExtraction line) =>
      _ReceiptLineItemEditor(
        description: line.description,
        quantity: line.quantity,
        unitPrice: MoneyEx.fromInt(line.unitPrice),
        lineTotalExTax: MoneyEx.fromInt(line.lineTotalExTax),
        taxAmount: MoneyEx.fromInt(line.taxAmount),
        lineTotalIncTax: MoneyEx.fromInt(line.lineTotalIncTax),
        matchedTaskItemId: null,
        expenseCategory: ReceiptExpenseCategory.materials,
        confidence: line.confidence,
        source: 'photo_ocr',
      );

  Money get lineTotalExTax => lineTotalExTaxController.money ?? MoneyEx.zero;

  Money get unitPrice => unitPriceController.money ?? MoneyEx.zero;

  Money get lineTotalIncTax => lineTotalIncTaxController.money ?? MoneyEx.zero;

  double get quantity => double.tryParse(quantityController.text.trim()) ?? 1;

  String get description => descriptionController.text.trim();

  bool get isReturn =>
      lineTotalExTax.isNegative ||
      unitPrice.isNegative ||
      lineTotalIncTax.isNegative;

  ReceiptLineMatchInput matchInput({
    required DateTime receiptDate,
    required int? supplierId,
  }) => ReceiptLineMatchInput(
    description: description,
    lineTotalExTax: lineTotalExTax,
    receiptDate: receiptDate,
    supplierId: supplierId,
  );

  ReceiptLineItem toEntity({required int receiptId}) =>
      ReceiptLineItem.forInsert(
        receiptId: receiptId,
        description: descriptionController.text.trim(),
        quantity: double.tryParse(quantityController.text.trim()) ?? 1,
        unitPrice: unitPriceController.money ?? MoneyEx.zero,
        lineTotalExTax: lineTotalExTaxController.money ?? MoneyEx.zero,
        taxAmount: taxAmountController.money ?? MoneyEx.zero,
        lineTotalIncTax: lineTotalIncTaxController.money ?? MoneyEx.zero,
        matchedTaskItemId: matchedTaskItemId,
        expenseCategory: expenseCategory,
        confidence: confidence,
        source: source,
      );

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    lineTotalExTaxController.dispose();
    taxAmountController.dispose();
    lineTotalIncTaxController.dispose();
    customTaxRateController.dispose();
  }
}

T? _firstOrNull<T>(List<T> values) => values.isEmpty ? null : values.first;
