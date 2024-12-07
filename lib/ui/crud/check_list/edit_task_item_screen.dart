import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:money2/money2.dart';

import '../../../dao/dao_supplier.dart';
import '../../../dao/dao_system.dart';
import '../../../dao/dao_task_item.dart';
import '../../../dao/dao_task_item_type.dart';
import '../../../entity/job.dart';
import '../../../entity/supplier.dart';
import '../../../entity/system.dart';
import '../../../entity/task.dart';
import '../../../entity/task_item.dart';
import '../../../entity/task_item_type.dart';
import '../../../util/fixed_ex.dart';
import '../../../util/measurement_type.dart';
import '../../../util/money_ex.dart';
import '../../../util/platform_ex.dart';
import '../../widgets/async_state.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/select/select_supplier.dart';
import '../base_nested/edit_nested_screen.dart';
import 'dimensions.dart';

class TaskItemEditScreen extends StatefulWidget {
  const TaskItemEditScreen({
    required this.parent,
    required this.billingType,
    required this.hourlyRate,
    super.key,
    this.taskItem,
  });

  final Task? parent;
  final TaskItem? taskItem;
  final BillingType billingType; // 'Fixed Price' or 'Time and Materials'
  final Money hourlyRate;

  @override
  // ignore: library_private_types_in_public_api
  _TaskItemEditScreenState createState() => _TaskItemEditScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TaskItem?>('taskItem', taskItem));
  }
}

class _TaskItemEditScreenState extends AsyncState<TaskItemEditScreen, System>
    implements NestedEntityState<TaskItem> {
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

  LabourEntryMode _labourEntryMode = LabourEntryMode.hours;
  @override
  TaskItem? currentEntity;

  final globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.taskItem;

    _descriptionController =
        TextEditingController(text: currentEntity?.description);
    _estimatedMaterialUnitCostController = TextEditingController(
        text: currentEntity?.estimatedMaterialUnitCost.toString());
    _estimatedMaterialQuantityController = TextEditingController(
        text:
            (currentEntity?.estimatedMaterialQuantity ?? Fixed.one).toString());
    _estimatedLabourHoursController = TextEditingController(
        text: currentEntity?.estimatedLabourHours.toString());

    _estimatedLabourCostController = TextEditingController(
        text: currentEntity?.estimatedLabourCost.toString());

    _marginController =
        TextEditingController(text: currentEntity?.margin.toString());
    _chargeController = TextEditingController(
        text: currentEntity
            ?.getCharge(widget.billingType, widget.hourlyRate)
            .toString());

    _dimension1Controller =
        TextEditingController(text: currentEntity?.dimension1.toString());
    _dimension2Controller =
        TextEditingController(text: currentEntity?.dimension2.toString());
    _dimension3Controller =
        TextEditingController(text: currentEntity?.dimension3.toString());

    _urlController = TextEditingController(text: currentEntity?.url);
    _labourEntryMode = currentEntity?.labourEntryMode ?? LabourEntryMode.hours;

    _descriptionFocusNode = FocusNode();
  }

  @override
  Future<System> asyncInitState() async {
    final system = await DaoSystem().get();
    var selectedUnits = June.getState(SelectedUnits.new).selected;

    June.getState(SelectedSupplier.new).selected = currentEntity?.supplierId;

    final selectedDimensionType =
        currentEntity?.measurementType ?? MeasurementType.length;
    June.getState(SelectedMeasurementType.new).selected = selectedDimensionType;

    final defaultDimensionType =
        system!.preferredUnitSystem == PreferredUnitSystem.metric
            ? selectedDimensionType.defaultMetric
            : selectedDimensionType.defaultImperial;

    selectedUnits =
        selectedUnits ?? currentEntity?.units ?? defaultDimensionType;
    June.getState(SelectedUnits.new).selected = selectedUnits;
    June.getState(SelectedMeasurementType.new).selected =
        currentEntity?.measurementType;
    June.getState(SelectedCheckListItemType.new).selected =
        currentEntity?.itemTypeId;
    return system;
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
        future: initialised,
        builder: (context, system) => NestedEntityEditScreen<TaskItem, Task>(
          key: globalKey,
          entityName: 'Task Item',
          dao: DaoTaskItem(),
          onInsert: (taskItem) async => DaoTaskItem().insert(taskItem!),
          entityState: this,
          editor: (taskItem) => Column(
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
              _chooseItemType(taskItem),
              if (June.getState(SelectedCheckListItemType.new).selected !=
                  0) ...[
                _chooseSupplier(taskItem),
                ..._buildFieldsBasedOnItemType(),
                HMBTextField(
                  controller: _urlController,
                  labelText: 'Reference URL',
                  keyboardType: TextInputType.url,
                ),
                DimensionWidget(
                  dimension1Controller: _dimension1Controller,
                  dimension2Controller: _dimension2Controller,
                  dimension3Controller: _dimension3Controller,
                  taskItem: taskItem,
                ),
              ],
            ],
          ),
        ),
      );

  HMBDroplist<TaskItemType> _chooseItemType(TaskItem? taskItem) =>
      HMBDroplist<TaskItemType>(
        title: 'Item Type',
        selectedItem: () async => DaoTaskItemType()
            .getById(June.getState(SelectedCheckListItemType.new).selected),
        items: (filter) async => DaoTaskItemType().getByFilter(filter),
        format: (checklistItemType) => checklistItemType.name,
        onChanged: (itemType) {
          setState(() {
            June.getState(SelectedCheckListItemType.new).selected =
                itemType?.id;
          });
        },
      );

  HMBDroplist<Supplier> _chooseSupplier(TaskItem? taskItem) =>
      HMBDroplist<Supplier>(
        title: 'Supplier',
        selectedItem: () async =>
            June.getState(SelectedSupplier.new).selected != 0
                ? DaoSupplier()
                    .getById(June.getState(SelectedSupplier.new).selected)
                : null,
        items: (filter) async => DaoSupplier().getByFilter(filter),
        format: (supplier) => supplier.name,
        onChanged: (supplier) {
          setState(() {
            June.getState(SelectedSupplier.new).selected = supplier?.id;
          });
        },
        required: false,
      );

  List<Widget> _buildFieldsBasedOnItemType() {
    switch (June.getState(SelectedCheckListItemType.new).selected) {
      case 0:
        return [];
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
        HMBDroplist<LabourEntryMode>(
            title: 'Labour Entry Mode',
            selectedItem: () async => _labourEntryMode,
            items: (filter) async => LabourEntryMode.values,
            format: LabourEntryMode.getDisplay,
            onChanged: (mode) {
              setState(() {
                _labourEntryMode = mode ?? LabourEntryMode.hours;
              });
            },
            required: false),
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
            onChanged: (value) =>
                _calculateChargeFromMargin(_marginController.text),
          ),
        _buildMarginAndChargeFields(),
      ];

  void _calculateChargeFromMargin(String? marginValue) {
    final margin = FixedEx.tryParse(marginValue).divide(100);
    final estimatedLabourHours =
        FixedEx.tryParse(_estimatedLabourHoursController.text);

    final unitCost =
        MoneyEx.tryParse(_estimatedMaterialUnitCostController.text);

    final estimatedLabourCost =
        MoneyEx.tryParse(_estimatedLabourCostController.text);

    final estimatedMaterialQuantity =
        FixedEx.tryParse(_estimatedMaterialQuantityController.text);

    var charge = MoneyEx.tryParse(_chargeController.text);

    charge = DaoTaskItem().calculateCharge(
        itemTypeId: June.getState(SelectedCheckListItemType.new).selected,
        margin: margin,
        labourEntryMode: _labourEntryMode,
        estimatedLabourHours: estimatedLabourHours,
        hourlyRate: widget.hourlyRate,
        estimatedMaterialUnitCost: unitCost,
        estimatedLabourCost: estimatedLabourCost,
        estimatedMaterialQuantity: estimatedMaterialQuantity,
        charge: charge);

    _chargeController.text = charge.toString();
  }

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
        _buildMarginAndChargeFields(),
      ];

  /// Materials or tools that we have in stock,
  /// which we may optionally charge for.
  List<Widget> _buildStockFields() => [
        HMBTextField(
          controller: _estimatedMaterialUnitCostController,
          labelText: 'Unit Cost',
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
        HMBTextField(
          controller: _chargeController,
          labelText: 'Charge',
          keyboardType: TextInputType.number,
          onChanged: (value) {
            _calculateChargeFromMargin(_marginController.text);
          },
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
            onChanged: (value) {
              _calculateChargeFromMargin(_marginController.text);
            },
          ),
        ],
      );

  void _calculateEstimatedCostFromHours(String? hoursValue) {
    final estimatedHours = FixedEx.tryParse(hoursValue);
    final estimatedCost = widget.hourlyRate.multiplyByFixed(estimatedHours);
    _estimatedLabourCostController.text = estimatedCost.toString();
  }

  @override
  Future<TaskItem> forUpdate(TaskItem taskItem) async => TaskItem.forUpdate(
        entity: taskItem,
        taskId: taskItem.taskId,
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
        charge: Money.tryParse(_chargeController.text, isoCode: 'AUD'),
        chargeSet: taskItem.chargeSet,
        margin: Percentage.tryParse(_marginController.text)??Percentage.zero,
        completed: taskItem.completed,
        billed: false,
        labourEntryMode: _labourEntryMode,
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
        supplierId: June.getState(SelectedSupplier.new).selected,
      );

  @override
  Future<TaskItem> forInsert() async => TaskItem.forInsert(
        taskId: widget.parent!.id,
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
        charge: Money.tryParse(_chargeController.text, isoCode: 'AUD'),
        chargeSet: false,
        margin: Percentage.tryParse(_marginController.text)??Percentage.zero,
        labourEntryMode: _labourEntryMode,
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
        supplierId: June.getState(SelectedSupplier.new).selected,
      );

  @override
  void refresh() {
    setState(() {});
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
