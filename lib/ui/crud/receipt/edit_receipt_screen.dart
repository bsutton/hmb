// lib/src/ui/receipt/receipt_edit_screen.dart
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/money_ex.dart';
import '../../widgets/fields/fields.g.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/select/select_supplier.dart';
import '../../widgets/widgets.g.dart';
import '../base_full_screen/edit_entity_screen.dart';
import '../task/photo_crud.dart';

class ReceiptEditScreen extends StatefulWidget {
  const ReceiptEditScreen({super.key, this.receipt});
  final Receipt? receipt;

  @override
  State<ReceiptEditScreen> createState() => _ReceiptEditScreenState();
}

class _ReceiptEditScreenState extends DeferredState<ReceiptEditScreen>
    implements EntityState<Receipt> {
  late DateTime _date;
  Job? _job;
  int? _supplierId;

  @override
  Receipt? currentEntity;

  // NEW: selector state
  final selectedSupplier = SelectedSupplier();

  late HMBMoneyEditingController _totalExclCtrl;
  late HMBMoneyEditingController _taxCtrl;
  late HMBMoneyEditingController _totalInclCtrl;
  late PhotoController<Receipt> _photoCtrl;

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
    _job = await DaoJob().getById(currentEntity?.jobId);
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
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder:
        (_) => EntityEditScreen<Receipt>(
          entityName: 'Receipt',
          dao: DaoReceipt(),
          entityState: this,
          editor: (e, {required isNew}) => _buildEditor(),
          crossValidator: _validateTotals,
        ),
  );

  Widget _buildEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Date
      HMBDateTimeField(
        mode: HMBDateTimeFieldMode.dateOnly,
        label: 'Receipt Date',
        initialDateTime: _date,
        onChanged: (v) => _date = v,
      ),

      // Job dropdown (unchanged)
      HMBDroplist<Job>(
        title: 'Select Job',
        selectedItem: () async => _job,
        // ignore: discarded_futures
        items: (filter) => DaoJob().getActiveJobs(filter),
        format: (job) => job.summary,
        onChanged: (job) {
          setState(() {
            _job = job;
          });
        },
      ),

      // SUPPLIER: now using your SelectSupplier widget
      SelectSupplier(
        selectedSupplier: selectedSupplier,
        isRequired: true,

        onSelected:
            (supplier) => setState(() {
              _supplierId = supplier?.id;
              selectedSupplier.selected = supplier?.id;
            }),
      ),

      // MONEY FIELDS: dollars entry
      HMBMoneyField(
        controller: _totalInclCtrl,
        labelText: 'Total Incl. Tax',
        fieldName: 'Total Including Tax',
        focusNode: _taxIncFocus,
      ),
      HMBMoneyField(
        controller: _taxCtrl,
        labelText: 'Tax',
        fieldName: 'Tax',
        focusNode: _taxFocus,
      ),
      HMBMoneyField(
        controller: _totalExclCtrl,
        labelText: 'Total Excl. Tax',
        fieldName: 'Total Excluding Tax',
        focusNode: _taxExFocus,
      ),

      const SizedBox(height: 16),

      // Photos
      PhotoCrud<Receipt>(
        key: ValueKey(currentEntity?.id),
        parentName: 'Receipt',
        parentType: ParentType.receipt,
        controller: _photoCtrl,
      ),
      const SizedBox(height: 16),
    ],
  );

  @override
  Future<Receipt> forUpdate(Receipt receipt) async => Receipt.forUpdate(
    entity: receipt,
    receiptDate: _date,
    jobId: _job!.id,
    supplierId: _supplierId!,
    totalExcludingTax: MoneyEx.tryParse(_totalExclCtrl.text),
    tax: MoneyEx.tryParse(_taxCtrl.text),
    totalIncludingTax: MoneyEx.tryParse(_totalInclCtrl.text),
  );

  @override
  Future<Receipt> forInsert() async => Receipt.forInsert(
    receiptDate: _date,
    jobId: _job!.id,
    supplierId: _supplierId!,
    totalExcludingTax: MoneyEx.tryParse(_totalExclCtrl.text),
    tax: MoneyEx.tryParse(_taxCtrl.text),
    totalIncludingTax: MoneyEx.tryParse(_totalInclCtrl.text),
  );

  @override
  void saved() {
    // update the controller to point at the newly‐saved entity
    _photoCtrl = PhotoController<Receipt>(
      parent: currentEntity,
      parentType: ParentType.receipt,
    );
    setState(() {});
  }

  void _recalculate() {
    if (_isCalculating) {
      return;
    }
    _isCalculating = true;

    final excl = _totalExclCtrl.money;
    final tax = _taxCtrl.money;
    final incl = _totalInclCtrl.money;

    final provided =
        [
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
    return true;
  }
}
