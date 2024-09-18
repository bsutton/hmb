import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:money2/money2.dart';

import '../../dao/dao_check_list_item_type.dart';
import '../../dao/dao_checklist_item.dart';
import '../../dao/dao_supplier.dart';
import '../../dao/dao_system.dart';
import '../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../entity/check_list.dart';
import '../../entity/check_list_item.dart';
import '../../entity/check_list_item_type.dart';
import '../../entity/entity.dart';
import '../../entity/job.dart';
import '../../entity/supplier.dart';
import '../../entity/system.dart';
import '../../util/fixed_ex.dart';
import '../../util/money_ex.dart';
import '../../util/platform_ex.dart';
import '../../widgets/hmb_droplist.dart';
import '../../widgets/hmb_text_field.dart';
import '../base_nested/edit_nested_screen.dart';
import 'dimensions.dart';

class CheckListItemEditScreen<P extends Entity<P>> extends StatefulWidget {
  const CheckListItemEditScreen({
    required this.parent,
    required this.daoJoin,
    required this.billingType, // Pass job type
    required this.hourlyRate,
    super.key,
    this.checkListItem,
  });
  final DaoJoinAdaptor daoJoin;
  final P parent;
  final CheckListItem? checkListItem;
  final BillingType billingType; // 'Fixed Price' or 'Time and Materials'
  final Money hourlyRate;

  @override
  // ignore: library_private_types_in_public_api
  _CheckListItemEditScreenState createState() =>
      _CheckListItemEditScreenState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        DiagnosticsProperty<CheckListItem?>('checkListItem', checkListItem));
  }
}

class _CheckListItemEditScreenState extends State<CheckListItemEditScreen>
    implements NestedEntityState<CheckListItem> {
  late TextEditingController _descriptionController;
  late TextEditingController _estimatedCostController;
  late TextEditingController _estimatedQuantityController;
  late TextEditingController _estimatedHoursController;
  late TextEditingController _chargeController;
  late TextEditingController _marginController;
  late TextEditingController _dimension1Controller;
  late TextEditingController _dimension2Controller;
  late TextEditingController _dimension3Controller;
  late TextEditingController _urlController;

  late FocusNode _descriptionFocusNode;

  int? _selectedSupplierId;
  int? _selectedItemTypeId;
  LabourEntryMode _labourEntryMode = LabourEntryMode.hours;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.checkListItem?.description ?? '');
    _estimatedCostController = TextEditingController(
        text: widget.checkListItem?.estimatedMaterialCost?.toString() ?? '');
    _estimatedQuantityController = TextEditingController(
        text:
            widget.checkListItem?.estimatedMaterialQuantity?.toString() ?? '1');
    _estimatedHoursController = TextEditingController(
        text: widget.checkListItem?.estimatedLabour?.toString() ?? '');
    _chargeController = TextEditingController(
        text: widget.checkListItem?.charge.toString() ?? '');
    _marginController = TextEditingController(
        text: widget.checkListItem?.margin.toString() ?? '');
    TextEditingController(text: widget.checkListItem?.description);
    // _costController = TextEditingController(
    //     text: widget.checkListItem?.estimatedMaterialCost.toString());
    // _quantityController = TextEditingController(
    //     text: (widget.checkListItem?.estimatedMaterialQuantity ?? Fixed.one)
    //         .toString());
    // _effortInHoursController = TextEditingController(
    //     text: widget.checkListItem?.estimatedLabour.toString());

    _marginController =
        TextEditingController(text: widget.checkListItem?.margin.toString());

    _chargeController =
        TextEditingController(text: widget.checkListItem?.charge.toString());

    _dimension1Controller = TextEditingController(
        text: widget.checkListItem?.dimension1.toString() ?? '');
    _dimension2Controller = TextEditingController(
        text: widget.checkListItem?.dimension2.toString() ?? '');
    _dimension3Controller = TextEditingController(
        text: widget.checkListItem?.dimension3.toString() ?? '');
    _urlController =
        TextEditingController(text: widget.checkListItem?.url ?? '');
    _selectedSupplierId = widget.checkListItem?.supplierId;

    _descriptionFocusNode = FocusNode();

    _selectedItemTypeId = widget.checkListItem?.itemTypeId ?? 0;

    _labourEntryMode = LabourEntryMode.hours;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _estimatedCostController.dispose();
    _estimatedQuantityController.dispose();
    _estimatedHoursController.dispose();
    _chargeController.dispose();
    _marginController.dispose();
    // _costController.dispose();
    // _quantityController.dispose();
    // _effortInHoursController.dispose();
    _chargeController.dispose();
    _dimension1Controller.dispose();
    _dimension2Controller.dispose();
    _dimension3Controller.dispose();
    _urlController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilderEx<System?>(
      // ignore: discarded_futures
      future: DaoSystem().get(),
      builder: (context, system) =>
          NestedEntityEditScreen<CheckListItem, CheckList>(
            entity: widget.checkListItem,
            entityName: 'Check List Item',
            dao: DaoCheckListItem(),
            onInsert: (checkListItem) async =>
                widget.daoJoin.insertForParent(checkListItem!, widget.parent),
            entityState: this,
            editor: (checklistItem) {
              _initSelected(checklistItem, system);

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HMBTextField(
                      controller: _descriptionController,
                      focusNode: _descriptionFocusNode,
                      autofocus: isNotMobile,
                      labelText: 'Description',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the description';
                        }
                        return null;
                      },
                    ),
                    _buildItemTypeDropdown(),
                    _chooseSupplier(),
                    _buildDynamicFields(),
                    HMBTextField(
                      controller: _urlController,
                      labelText: 'Reference URL',
                      keyboardType: TextInputType.url,
                    ),
                    DimensionWidget(
                      dimension1Controller: _dimension1Controller,
                      dimension2Controller: _dimension2Controller,
                      dimension3Controller: _dimension3Controller,
                      checkListItem: checklistItem,
                    ),
                  ],
                ),
              );
            },
          ));

  Widget _buildItemTypeDropdown() => HMBDroplist<CheckListItemType>(
        title: 'Item Type',
        selectedItem: () async =>
            DaoCheckListItemType().getById(_selectedItemTypeId ?? 0),
        items: (filter) async => DaoCheckListItemType().getByFilter(filter),
        format: (checklistItemType) => checklistItemType.name,
        onChanged: (itemType) {
          setState(() {
            _selectedItemTypeId = itemType?.id;
          });
        },
      );

  Widget _chooseSupplier() => HMBDroplist<Supplier>(
        title: 'Supplier',
        selectedItem: () async => _selectedSupplierId != null
            ? DaoSupplier().getById(_selectedSupplierId)
            : null,
        items: (filter) async => DaoSupplier().getByFilter(filter),
        format: (supplier) => supplier.name,
        onChanged: (supplier) {
          setState(() {
            _selectedSupplierId = supplier?.id;
          });
        },
        required: false,
      );

  Widget _buildDynamicFields() {
    switch (_selectedItemTypeId) {
      case 5: // Labour
        return _buildLabourFields();
      case 1: // Materials - buy
      case 3: // Tools - buy
        return _buildBuyItemsFields();
      case 2: // Materials - stock
      case 4: // Tools - stock
        return _buildStockItemsFields();
      default:
        return Container();
    }
  }

  Widget _buildLabourFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLabourEntryModeSwitch(),
          if (_labourEntryMode == LabourEntryMode.hours)
            HMBTextField(
              controller: _estimatedHoursController,
              labelText: 'Estimated Hours',
              keyboardType: TextInputType.number,
              onChanged: _calculateEstimatedCostFromHours,
            )
          else
            HMBTextField(
              controller: _estimatedCostController,
              labelText: 'Estimated Cost',
              keyboardType: TextInputType.number,
              onChanged: _calculateChargeFromMargin,
            ),
          _buildMarginAndChargeFields(),
        ],
      );

  Widget _buildLabourEntryModeSwitch() => Row(
        children: [
          const Text('Enter Labour as: '),
          Expanded(
            child: DropdownButton<LabourEntryMode>(
              value: _labourEntryMode,
              items: [
                DropdownMenuItem(
                    value: LabourEntryMode.hours,
                    child: Text(
                        LabourEntryMode.getDisplay(LabourEntryMode.hours))),
                DropdownMenuItem(
                    value: LabourEntryMode.dollars,
                    child: Text(
                        LabourEntryMode.getDisplay(LabourEntryMode.dollars))),
              ],
              onChanged: (value) {
                setState(() {
                  _labourEntryMode = value ?? LabourEntryMode.hours;
                });
              },
            ),
          ),
        ],
      );

  void _calculateEstimatedCostFromHours(String? value) {
    final estimatedHours = FixedEx.tryParse(value);
    final estimatedCost = widget.hourlyRate.multiplyByFixed(estimatedHours);
    _estimatedCostController.text = estimatedCost.toString();
    _calculateChargeFromMargin(_marginController.text);
  }

  Widget _buildBuyItemsFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HMBTextField(
            controller: _estimatedCostController,
            labelText: 'Estimated Cost',
            keyboardType: TextInputType.number,
            onChanged: _calculateChargeFromMargin,
          ),
          HMBTextField(
            controller: _estimatedQuantityController,
            labelText: 'Quantity',
            keyboardType: TextInputType.number,
            onChanged: _calculateChargeFromMargin,
          ),
          _buildMarginAndChargeFields(),
        ],
      );

  Widget _buildStockItemsFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HMBTextField(
            controller: _estimatedQuantityController,
            labelText: 'Quantity',
            keyboardType: TextInputType.number,
            onChanged: _calculateChargeFromMargin,
          ),
          HMBTextField(
            controller: _chargeController,
            labelText: 'Charge',
            keyboardType: TextInputType.number,
          ),
        ],
      );

  Widget _buildMarginAndChargeFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HMBTextField(
            controller: _marginController,
            labelText: 'Margin (%)',
            keyboardType: TextInputType.number,
            onChanged: _calculateChargeFromMargin,
          ),
          HMBTextField(
            controller: _chargeController,
            labelText: 'Charge',
            keyboardType: TextInputType.number,
            onChanged: _calculateMarginFromCharge,
          ),
        ],
      );

  void _calculateChargeFromMargin(String? value) {
    final estimatedCost = MoneyEx.tryParse(_estimatedCostController.text);
    final quantity =
        FixedEx.tryParseOrElse(_estimatedQuantityController.text, Fixed.one);
    final totalCost = estimatedCost.multiplyByFixed(quantity);
    final margin = FixedEx.tryParse(_marginController.text);
    final charge = totalCost + (totalCost.multiplyByFixed(margin.divide(100)));
    _chargeController.text = charge.toString();
  }

  void _calculateMarginFromCharge(String? value) {
    final estimatedCost = MoneyEx.tryParse(_estimatedCostController.text);
    final quantity =
        FixedEx.tryParseOrElse(_estimatedQuantityController.text, Fixed.one);
    final totalCost = estimatedCost.multiplyByFixed(quantity);
    final charge = MoneyEx.tryParse(value);
    if (totalCost > MoneyEx.zero) {
      final margin = (charge - totalCost)
          .dividedBy(totalCost.multiplyByFixed(Fixed.fromInt(100)));
      _marginController.text = margin.toString();
    }
  }

  @override
  Future<CheckListItem> forUpdate(CheckListItem checkListItem) async =>
      _buildCheckListItem(checkListItem);

  @override
  Future<CheckListItem> forInsert() async => _buildCheckListItem(null);

  CheckListItem _buildCheckListItem(CheckListItem? existingItem) {
    final itemTypeId = _selectedItemTypeId ?? existingItem?.itemTypeId ?? 0;
    Money? estimatedCost;
    Fixed? estimatedHours;
    Fixed? estimatedQuantity;

    if (itemTypeId == 5) {
      // Labour
      if (_labourEntryMode == LabourEntryMode.hours) {
        estimatedHours =
            FixedEx.tryParseOrElse(_estimatedHoursController.text, Fixed.zero);
        estimatedCost = widget.hourlyRate.multiplyByFixed(estimatedHours);
      } else {
        estimatedCost = MoneyEx.tryParse(_estimatedCostController.text);
        estimatedHours = null;
      }
      estimatedQuantity = null;
    } else if (itemTypeId == 1 || itemTypeId == 3) {
      // Materials - buy or Tools - buy
      estimatedCost = MoneyEx.tryParse(_estimatedCostController.text);
      estimatedQuantity =
          FixedEx.tryParseOrElse(_estimatedQuantityController.text, Fixed.one);
    } else if (itemTypeId == 2 || itemTypeId == 4) {
      // Materials - stock or Tools - stock
      estimatedCost = null;
      estimatedQuantity =
          FixedEx.tryParseOrElse(_estimatedQuantityController.text, Fixed.one);
    }

    final charge = MoneyEx.tryParse(_chargeController.text);
    final margin = FixedEx.tryParse(_marginController.text);

    final baseItem = CheckListItem(
      id: existingItem?.id ?? 0,
      checkListId: widget.parent.id,
      description: _descriptionController.text,
      itemTypeId: itemTypeId,
      estimatedMaterialCost: estimatedCost,
      estimatedLabour: estimatedHours,
      estimatedMaterialQuantity: estimatedQuantity,
      estimatedCost: estimatedCost,
      charge: charge,
      margin: margin,
      completed: existingItem?.completed ?? false,
      billed: existingItem?.billed ?? false,
      invoiceLineId: existingItem?.invoiceLineId,
      createdDate: existingItem?.createdDate ?? DateTime.now(),
      modifiedDate: DateTime.now(),
      measurementType:
          June.getState(SelectedMeasurementType.new).selectedOrDefault,
      dimension1:
          FixedEx.tryParseOrElse(_dimension1Controller.text, Fixed.zero),
      dimension2:
          FixedEx.tryParseOrElse(_dimension2Controller.text, Fixed.zero),
      dimension3:
          FixedEx.tryParseOrElse(_dimension3Controller.text, Fixed.zero),
      units: June.getState(SelectedUnits.new).selectedOrDefault,
      url: _urlController.text,
      supplierId: _selectedSupplierId,
    );

    return existingItem == null
        ? CheckListItem.forInsert(
            checkListId: baseItem.checkListId,
            description: baseItem.description,
            itemTypeId: baseItem.itemTypeId,
            estimatedMaterialCost: baseItem.estimatedMaterialCost,
            estimatedLabour: baseItem.estimatedLabour,
            estimatedMaterialQuantity: baseItem.estimatedMaterialQuantity,
            estimatedCost: baseItem.estimatedCost,
            charge: baseItem.charge,
            margin: baseItem.margin,
            measurementType: baseItem.measurementType,
            dimension1: baseItem.dimension1,
            dimension2: baseItem.dimension2,
            dimension3: baseItem.dimension3,
            units: baseItem.units,
            url: baseItem.url,
            supplierId: baseItem.supplierId,
          )
        : CheckListItem.forUpdate(
            entity: existingItem,
            checkListId: baseItem.checkListId,
            description: baseItem.description,
            itemTypeId: baseItem.itemTypeId,
            estimatedMaterialCost: baseItem.estimatedMaterialCost,
            estimatedLabour: baseItem.estimatedLabour,
            estimatedMaterialQuantity: baseItem.estimatedMaterialQuantity,
            estimatedCost: baseItem.estimatedCost,
            charge: baseItem.charge,
            margin: baseItem.margin,
            completed: baseItem.completed,
            billed: baseItem.billed,
            measurementType: baseItem.measurementType,
            dimension1: baseItem.dimension1,
            dimension2: baseItem.dimension2,
            dimension3: baseItem.dimension3,
            units: baseItem.units,
            url: baseItem.url,
            supplierId: baseItem.supplierId,
          );
  }
  //   measurementType:
  //       June.getState(SelectedMeasurementType.new).selectedOrDefault,
  //   dimension1:
  //       Fixed.tryParse(_dimension1Controller.text, scale: 3) ?? Fixed.zero,
  //   dimension2:
  //       Fixed.tryParse(_dimension2Controller.text, scale: 3) ?? Fixed.zero,
  //   dimension3:
  //       Fixed.tryParse(_dimension3Controller.text, scale: 3) ?? Fixed.zero,
  //   units: June.getState(SelectedUnits.new).selectedOrDefault,
  //   url: _urlController.text,
  //   supplierId: _selectedSupplierId, // Save Supplier ID
  // );

  @override
  void refresh() {
    setState(() {});
  }

  void _initSelected(CheckListItem? checklistItem, System? system) {
    _selectedItemTypeId = checklistItem?.itemTypeId ?? _selectedItemTypeId;
    // Additional initialization if needed
  }
}
