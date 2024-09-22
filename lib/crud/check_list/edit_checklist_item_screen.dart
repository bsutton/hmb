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
import '../../util/measurement_type.dart';
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
  late TextEditingController _estimatedMaterialUnitCostController;
  late TextEditingController _estimatedMaterialQuantityController;
  late TextEditingController _estimatedLabourHoursController;
  late TextEditingController _estimatedLabourCostController;
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
        TextEditingController(text: widget.checkListItem?.description);
    _estimatedMaterialUnitCostController = TextEditingController(
        text: widget.checkListItem?.estimatedMaterialUnitCost.toString());
    _estimatedMaterialQuantityController = TextEditingController(
        text: (widget.checkListItem?.estimatedMaterialQuantity ?? Fixed.one)
            .toString());
    _estimatedLabourHoursController = TextEditingController(
        text: widget.checkListItem?.estimatedLabourHours.toString());

    _estimatedLabourCostController = TextEditingController(
        text: widget.checkListItem?.estimatedLabourCost.toString());

    _marginController =
        TextEditingController(text: widget.checkListItem?.margin.toString());
    _chargeController =
        TextEditingController(text: widget.checkListItem?.charge.toString());

    _dimension1Controller = TextEditingController(
        text: widget.checkListItem?.dimension1.toString());
    _dimension2Controller = TextEditingController(
        text: widget.checkListItem?.dimension2.toString());
    _dimension3Controller = TextEditingController(
        text: widget.checkListItem?.dimension3.toString());

    _urlController = TextEditingController(text: widget.checkListItem?.url);

    _selectedSupplierId = widget.checkListItem?.supplierId;
    _selectedItemTypeId = widget.checkListItem?.itemTypeId;

    _descriptionFocusNode = FocusNode();

    June.getState(SelectedUnits.new).selected = null;
    June.getState(SelectedMeasurementType.new).selected = null;
    June.getState(SelectedCheckListItemType.new).selected = null;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _estimatedMaterialUnitCostController.dispose();
    _estimatedMaterialQuantityController.dispose();
    _estimatedLabourHoursController.dispose();
    _estimatedLabourCostController.dispose();
    _marginController.dispose();
    _chargeController.dispose();
    _dimension1Controller.dispose();
    _dimension2Controller.dispose();
    _dimension3Controller.dispose();
    _urlController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
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
            return Column(
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
                _chooseItemType(checklistItem),
                _chooseSupplier(checklistItem),
                ..._buildFieldsBasedOnItemType(),
                _buildMarginAndChargeFields(),
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
            );
          },
        ),
      );

  HMBDroplist<CheckListItemType> _chooseItemType(
          CheckListItem? checkListItem) =>
      HMBDroplist<CheckListItemType>(
        title: 'Item Type',
        selectedItem: () async =>
            DaoCheckListItemType().getById(_selectedItemTypeId ?? 0),
        items: (filter) async => DaoCheckListItemType().getByFilter(filter),
        format: (checklistItemType) => checklistItemType.name,
        onChanged: (itemType) {
          setState(() {
            _selectedItemTypeId = itemType?.id;
            June.getState(SelectedCheckListItemType.new).selected =
                _selectedItemTypeId;
          });
        },
      );

  HMBDroplist<Supplier> _chooseSupplier(CheckListItem? checkListItem) =>
      HMBDroplist<Supplier>(
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

  List<Widget> _buildFieldsBasedOnItemType() {
    switch (_selectedItemTypeId) {
      case 5: // Labour
        return _buildLabourFields();
      case 1: // Materials - buy
      case 3: // Tools - buy
        return _buildBuyFields();
      case 2: // Materials - stock
      case 4: // Tools - stock
        return _buildStockFields();
      default:
        return [];
    }
  }

  List<Widget> _buildLabourFields() => [
        _buildLabourEntryModeSwitch(),
        if (_labourEntryMode == LabourEntryMode.hours)
          HMBTextField(
            controller: _estimatedLabourHoursController,
            labelText: 'Estimated Hours',
            keyboardType: TextInputType.number,
            onChanged: (value) {
              _calculateEstimatedCostFromHours(value);
              _calculateChargeFromMargin(_marginController.text);
            },
          )
        else
          HMBTextField(
            controller: _estimatedLabourCostController,
            labelText: 'Estimated Cost',
            keyboardType: TextInputType.number,
            onChanged: _calculateChargeFromMargin,
          ),
      ];

  void _calculateChargeFromMargin(String? marginValue) {
    final margin = FixedEx.tryParse(marginValue).divide(100);

    FixedEx.tryParse(_estimatedLabourHoursController.text);

    final estimatedLabourHours =
        FixedEx.tryParse(_estimatedLabourHoursController.text);

    final unitCost =
        MoneyEx.tryParse(_estimatedMaterialUnitCostController.text);

    final estimatedLabourCost =
        MoneyEx.tryParse(_estimatedLabourCostController.text);

    final estimatedMaterailQuantity =
        FixedEx.tryParse(_estimatedMaterialQuantityController.text);

    var charge = MoneyEx.tryParse(_chargeController.text);

    charge = DaoCheckListItem().calculateChargeFromMargin(
        itemTypeId: _selectedItemTypeId,
        margin: margin,
        labourEntryMode: _labourEntryMode,
        estimatedLabobourHours: estimatedLabourHours,
        hourlyRate: widget.hourlyRate,
        estimatedMaterailUnitCost: unitCost,
        estimatedLabourCost: estimatedLabourCost,
        estimatedMaterialQuantity: estimatedMaterailQuantity,
        charge: charge);

    _chargeController.text = charge.toString();
  }

  Widget _buildLabourEntryModeSwitch() => HMBDroplist<LabourEntryMode>(
        title: 'Enter Labour as:',
        selectedItem: () async => _labourEntryMode,
        items: (filter) async => LabourEntryMode.values,
        format: LabourEntryMode.getDisplay,
        onChanged: (mode) {
          setState(() {
            _labourEntryMode = mode ?? LabourEntryMode.hours;
          });
        },
        required: false,
      );

  List<Widget> _buildBuyFields() => [
        HMBTextField(
          controller: _estimatedMaterialUnitCostController,
          labelText: 'Estimated Unit Cost',
          keyboardType: TextInputType.number,
          onChanged: (value) {
            _calculateChargeFromMargin(_marginController.text);
          },
        ),
        HMBTextField(
          controller: _estimatedMaterialQuantityController,
          labelText: 'Quantity',
          keyboardType: TextInputType.number,
          onChanged: (value) {
            _calculateChargeFromMargin(_marginController.text);
          },
        ),
      ];

  List<Widget> _buildStockFields() => [
        HMBTextField(
          controller: _chargeController,
          labelText: 'Charge',
          keyboardType: TextInputType.number,
        ),
        HMBTextField(
          controller: _estimatedMaterialQuantityController,
          labelText: 'Quantity',
          keyboardType: TextInputType.number,
        ),
      ];

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
          ),
        ],
      );

  void _calculateEstimatedCostFromHours(String? hoursValue) {
    final estimatedHours = FixedEx.tryParse(hoursValue);
    // Calculate the estimated cost using the hourly rate
    final estimatedCost = widget.hourlyRate.multiplyByFixed(estimatedHours);
    _estimatedLabourCostController.text = estimatedCost.toString();
  }

  @override
  Future<CheckListItem> forUpdate(CheckListItem checkListItem) async =>
      CheckListItem.forUpdate(
        entity: checkListItem,
        checkListId: checkListItem.checkListId,
        description: _descriptionController.text,
        itemTypeId: June.getState(SelectedCheckListItemType.new).selected,
        estimatedMaterialUnitCost:
            MoneyEx.tryParse(_estimatedMaterialUnitCostController.text),
        estimatedMaterialQuantity:
            FixedEx.tryParse(_estimatedMaterialQuantityController.text),
        estimatedLabourHours:
            FixedEx.tryParse(_estimatedLabourHoursController.text),
        estimatedLabourCost:
            MoneyEx.tryParse(_estimatedLabourCostController.text),
        charge: MoneyEx.tryParse(_chargeController.text),
        margin: FixedEx.tryParse(_marginController.text),
        completed: checkListItem.completed,
        billed: false,
        measurementType:
            June.getState(SelectedMeasurementType.new).selectedOrDefault,
        dimension1:
            Fixed.tryParse(_dimension1Controller.text, scale: 3) ?? Fixed.zero,
        dimension2:
            Fixed.tryParse(_dimension2Controller.text, scale: 3) ?? Fixed.zero,
        dimension3:
            Fixed.tryParse(_dimension3Controller.text, scale: 3) ?? Fixed.zero,
        units: June.getState(SelectedUnits.new).selectedOrDefault,
        url: _urlController.text,
        supplierId: _selectedSupplierId,
      );

  @override
  Future<CheckListItem> forInsert() async => CheckListItem.forInsert(
        checkListId: widget.parent.id,
        description: _descriptionController.text,
        itemTypeId: June.getState(SelectedCheckListItemType.new).selected,
        estimatedMaterialUnitCost:
            MoneyEx.tryParse(_estimatedMaterialUnitCostController.text),
        estimatedMaterialQuantity:
            FixedEx.tryParse(_estimatedMaterialQuantityController.text),
        estimatedLabourHours:
            FixedEx.tryParse(_estimatedLabourHoursController.text),
        estimatedLabourCost:
            MoneyEx.tryParse(_estimatedLabourCostController.text),
        charge: MoneyEx.tryParse(_chargeController.text),
        margin: FixedEx.tryParse(_marginController.text),
        measurementType:
            June.getState(SelectedMeasurementType.new).selectedOrDefault,
        dimension1:
            Fixed.tryParse(_dimension1Controller.text, scale: 3) ?? Fixed.zero,
        dimension2:
            Fixed.tryParse(_dimension2Controller.text, scale: 3) ?? Fixed.zero,
        dimension3:
            Fixed.tryParse(_dimension3Controller.text, scale: 3) ?? Fixed.zero,
        units: June.getState(SelectedUnits.new).selectedOrDefault,
        url: _urlController.text,
        supplierId: _selectedSupplierId,
      );

  @override
  void refresh() {
    setState(() {});
  }

  void _initSelected(CheckListItem? checklistItem, System? system) {
    June.getState(SelectedCheckListItemType.new).selected =
        checklistItem?.itemTypeId;
    final selectedDimensionType = checklistItem?.measurementType ?? length;
    June.getState(SelectedMeasurementType.new).selected = selectedDimensionType;

    var selectedUnits = June.getState(SelectedUnits.new).selected;

    final defaultDimensionType =
        system!.preferredUnitSystem == PreferredUnitSystem.metric
            ? selectedDimensionType.defaultMetric
            : selectedDimensionType.defaultImperial;

    selectedUnits =
        selectedUnits ?? checklistItem?.units ?? defaultDimensionType;
    June.getState(SelectedUnits.new).selected = selectedUnits;
  }
}

class SelectedCheckListItemType extends JuneState {
  int? _selected;

  set selected(int? value) {
    _selected = value;
    setState();
  }

  int get selected => _selected ?? 0;
}
