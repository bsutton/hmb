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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../../dao/dao_supplier.dart';
import '../../../dao/dao_system.dart';
import '../../../dao/dao_task_item.dart';
import '../../../entity/helpers/charge_mode.dart';
import '../../../entity/helpers/labour_calculator.dart';
import '../../../entity/helpers/material_calculator.dart';
import '../../../entity/job.dart';
import '../../../entity/supplier.dart';
import '../../../entity/system.dart';
import '../../../entity/task.dart';
import '../../../entity/task_item.dart';
import '../../../entity/task_item_type.dart';
import '../../../util/dart/app_settings.dart';
import '../../../util/dart/fixed_ex.dart';
import '../../../util/dart/measurement_type.dart';
import '../../../util/dart/money_ex.dart';
import '../../../util/flutter/platform_ex.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/select/hmb_select_supplier.dart';
import '../base_nested/edit_nested_screen.dart';
import 'dimensions.dart';

class TaskItemEditScreen extends StatefulWidget {
  final Task? parent;
  final TaskItem? taskItem;
  final BillingType billingType; // Fixed Price | Time and Materials
  final Money hourlyRate;

  const TaskItemEditScreen({
    required this.parent,
    required this.billingType,
    required this.hourlyRate,
    super.key,
    this.taskItem,
  });

  @override
  // ignore: library_private_types_in_public_api
  _TaskItemEditScreenState createState() => _TaskItemEditScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TaskItem?>('taskItem', taskItem));
  }
}

class _TaskItemEditScreenState extends DeferredState<TaskItemEditScreen>
    implements NestedEntityState<TaskItem> {
  late TextEditingController _descriptionController;
  late TextEditingController _purposeController;

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
  late ChargeMode _chargeMode;

  late FocusNode _descriptionFocusNode;

  LabourEntryMode _labourEntryMode = LabourEntryMode.hours;
  @override
  TaskItem? currentEntity;

  final GlobalKey<State<StatefulWidget>> _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.taskItem;

    _descriptionController = TextEditingController(
      text: currentEntity?.description,
    );

    _purposeController = TextEditingController(text: currentEntity?.purpose);
    _estimatedMaterialUnitCostController = TextEditingController(
      text: currentEntity?.estimatedMaterialUnitCost.toString(),
    );
    _estimatedMaterialQuantityController = TextEditingController(
      text: (currentEntity?.estimatedMaterialQuantity ?? Fixed.one).toString(),
    );
    _estimatedLabourHoursController = TextEditingController(
      text: currentEntity?.estimatedLabourHours.toString(),
    );

    _estimatedLabourCostController = TextEditingController(
      text: currentEntity?.estimatedLabourCost.toString(),
    );

    _marginController = TextEditingController(
      text: currentEntity?.margin.toString(),
    );
    _chargeController = TextEditingController(
      text: currentEntity
          ?.getTotalLineCharge(widget.billingType, widget.hourlyRate)
          .toString(),
    );

    _dimension1Controller = TextEditingController(
      text: currentEntity?.dimension1.toString(),
    );
    _dimension2Controller = TextEditingController(
      text: currentEntity?.dimension2.toString(),
    );
    _dimension3Controller = TextEditingController(
      text: currentEntity?.dimension3.toString(),
    );

    _urlController = TextEditingController(text: currentEntity?.url);
    _labourEntryMode = currentEntity?.labourEntryMode ?? LabourEntryMode.hours;

    _chargeMode = currentEntity?.chargeMode ?? ChargeMode.calculated;

    _descriptionFocusNode = FocusNode();
  }

  @override
  Future<System> asyncInitState() async {
    final system = await DaoSystem().get();
    final defaultMarginText = await AppSettings.getDefaultProfitMarginText();
    var selectedUnits = June.getState(SelectedUnits.new).selected;

    June.getState(SelectedSupplier.new).selected = currentEntity?.supplierId;

    final selectedDimensionType =
        currentEntity?.measurementType ?? MeasurementType.length;
    June.getState(SelectedMeasurementType.new).selected = selectedDimensionType;

    final defaultDimensionType =
        system.preferredUnitSystem == PreferredUnitSystem.metric
        ? selectedDimensionType.defaultMetric
        : selectedDimensionType.defaultImperial;

    selectedUnits =
        selectedUnits ?? currentEntity?.units ?? defaultDimensionType;
    June.getState(SelectedUnits.new).selected = selectedUnits;
    June.getState(SelectedMeasurementType.new).selected =
        currentEntity?.measurementType;
    June.getState(SelectedCheckListItemType.new).selected =
        currentEntity?.itemType;

    if (currentEntity == null && _marginController.text.trim().isEmpty) {
      _marginController.text = defaultMarginText;
      _calculateChargeFromMargin(defaultMarginText);
    }
    return system;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _purposeController.dispose();
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
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => NestedEntityEditScreen<TaskItem, Task>(
      key: _globalKey,
      entityName: 'Task Item',
      dao: DaoTaskItem(),
      onInsert: (taskItem, transaction) =>
          DaoTaskItem().insert(taskItem!, transaction),
      entityState: this,
      editor: (taskItem) => HMBColumn(
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
          HMBTextArea(controller: _purposeController, labelText: 'Purpose'),
          if (June.getState(SelectedCheckListItemType.new).selected !=
              null) ...[
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
        selectedItem: () async =>
            June.getState(SelectedCheckListItemType.new).selected,
        items: (filter) async => TaskItemType.getByFilter(filter),
        format: (checklistItemType) => checklistItemType.label,
        onChanged: (itemType) {
          setState(() {
            June.getState(SelectedCheckListItemType.new).selected = itemType;
          });
        },
      );

  HMBDroplist<Supplier> _chooseSupplier(TaskItem? taskItem) =>
      HMBDroplist<Supplier>(
        title: 'Supplier',
        selectedItem: () async =>
            June.getState(SelectedSupplier.new).selected != 0
            ? DaoSupplier().getById(
                June.getState(SelectedSupplier.new).selected,
              )
            : null,
        items: (filter) => DaoSupplier().getByFilter(filter),
        format: (supplier) => supplier.name,
        onChanged: (supplier) {
          setState(() {
            June.getState(SelectedSupplier.new).selected = supplier?.id;
          });
        },
        required: false,
      );

  List<Widget> _buildFieldsBasedOnItemType() {
    final widgets = <Widget>[];

    switch (June.getState(SelectedCheckListItemType.new).selected) {
      case TaskItemType.materialsBuy:
      case TaskItemType.toolsBuy:
      case TaskItemType.consumablesBuy:
        widgets.addAll(_buildBuyFields());
      case TaskItemType.materialsStock:
      case TaskItemType.toolsOwn:
      case TaskItemType.consumablesStock:
        widgets.addAll(_buildStockFields());
      case TaskItemType.labour:
        widgets.addAll(_buildLabourFields());
      case null:
    }

    return widgets;
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
      required: false,
    ),
    if (_labourEntryMode == LabourEntryMode.hours)
      HMBTextField(
        controller: _estimatedLabourHoursController,
        labelText: 'Estimated Hours',
        keyboardType: TextInputType.number,
        enabled: _chargeMode != ChargeMode.userDefined,
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
        enabled: _chargeMode != ChargeMode.userDefined,
        onChanged: (value) =>
            _calculateChargeFromMargin(_marginController.text),
      ),
    _buildMarginAndChargeFields(),
  ];

  void _calculateChargeFromMargin(String? marginValue) {
    final itemType = June.getState(SelectedCheckListItemType.new).selected!;
    final margin =
        Percentage.tryParse(marginValue ?? '0', decimalDigits: 3) ??
        Percentage.zero;

    // Parse form values
    final estHours = FixedEx.tryParse(_estimatedLabourHoursController.text);
    final estLabourCost = MoneyEx.tryParse(_estimatedLabourCostController.text);
    final estUnitCost = MoneyEx.tryParse(
      _estimatedMaterialUnitCostController.text,
    );
    final estQty = FixedEx.tryParse(_estimatedMaterialQuantityController.text);

    final isUserDefined = _chargeMode == ChargeMode.userDefined;
    final userCharge = isUserDefined
        ? Money.tryParse(_chargeController.text, isoCode: 'AUD') ?? MoneyEx.zero
        : null;

    // Build a transient TaskItem snapshot for calculators.
    final tmp = TaskItem.forInsert(
      taskId: widget.parent!.id,
      description: _descriptionController.text,
      purpose: _purposeController.text,
      itemType: itemType,
      chargeMode: _chargeMode,
      margin: margin,
      measurementType: June.getState(
        SelectedMeasurementType.new,
      ).selectedOrDefault,
      dimension1: Fixed.zero,
      dimension2: Fixed.zero,
      dimension3: Fixed.zero,
      units: June.getState(SelectedUnits.new).selectedOrDefault,
      url: _urlController.text,
      labourEntryMode: _labourEntryMode,
      estimatedMaterialUnitCost: estUnitCost,
      estimatedMaterialQuantity: estQty,
      estimatedLabourCost: estLabourCost,
      estimatedLabourHours: estHours,
      totalLineCharge: userCharge, // sets chargeMode when non-null
    );

    // Compute line total via calculators (line-level margin).
    Money lineTotal;
    if (itemType == TaskItemType.labour) {
      lineTotal = LabourCalculator(
        widget.billingType,
        tmp,
        widget.hourlyRate,
      ).totalCharge;
    } else {
      lineTotal = MaterialCalculator(
        widget.billingType,
        tmp,
      ).calcMaterialCharges(widget.billingType);
    }

    _chargeController.text = lineTotal.toString();
  }

  List<Widget> _buildBuyFields() => [
    HMBTextField(
      controller: _estimatedMaterialUnitCostController,
      labelText: 'Estimated Unit Cost (pre margin)',
      keyboardType: TextInputType.number,
      enabled: _chargeMode != ChargeMode.userDefined,
      onChanged: (value) => _calculateChargeFromMargin(_marginController.text),
    ),
    HMBTextField(
      controller: _estimatedMaterialQuantityController,
      labelText: 'Quantity',
      keyboardType: TextInputType.number,
      enabled: _chargeMode != ChargeMode.userDefined,
      onChanged: (value) => _calculateChargeFromMargin(_marginController.text),
    ),
    _buildMarginAndChargeFields(),
  ];

  /// Materials or tools that we have in stock,
  /// which we may optionally charge for.
  List<Widget> _buildStockFields() => [
    HMBTextField(
      controller: _estimatedMaterialUnitCostController,
      labelText: 'Unit Cost (pre margin)',
      keyboardType: TextInputType.number,
      enabled: _chargeMode != ChargeMode.userDefined,
      onChanged: (value) => _calculateChargeFromMargin(_marginController.text),
    ),
    HMBTextField(
      controller: _estimatedMaterialQuantityController,
      labelText: 'Quantity',
      keyboardType: TextInputType.number,
      enabled: _chargeMode != ChargeMode.userDefined,
      onChanged: (value) => _calculateChargeFromMargin(_marginController.text),
    ),
    _buildDirectChargeField(),
    HMBTextField(
      controller: _chargeController,
      labelText: 'Charge (line total)',
      keyboardType: TextInputType.number,
      enabled: _chargeMode == ChargeMode.userDefined,
      onChanged: (value) {
        if (_chargeMode != ChargeMode.userDefined) {
          _calculateChargeFromMargin(_marginController.text);
        }
      },
    ),
  ];

  Widget _buildMarginAndChargeFields() => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HMBTextField(
        controller: _marginController,
        labelText: 'Margin (%) – applied to line total',
        keyboardType: TextInputType.number,
        enabled: _chargeMode != ChargeMode.userDefined,
        onChanged: _calculateChargeFromMargin,
      ),
      _buildDirectChargeField(),
      HMBTextField(
        controller: _chargeController,
        labelText: 'Charge (line total)',
        keyboardType: TextInputType.number,
        enabled: _chargeMode == ChargeMode.userDefined,
        onChanged: (value) {
          if (_chargeMode != ChargeMode.userDefined) {
            _calculateChargeFromMargin(_marginController.text);
          }
        },
      ),
    ],
  );

  /// Control how charge is calculated.
  Widget _buildDirectChargeField() => SwitchListTile(
    title: const Text('Enter charge directly'),
    value: _chargeMode == ChargeMode.userDefined,
    onChanged: (val) => setState(() {
      _chargeMode = val ? ChargeMode.userDefined : ChargeMode.calculated;
      // if switching off manual, re-compute from margin/qty/hours
      if (_chargeMode != ChargeMode.userDefined) {
        _calculateChargeFromMargin(_marginController.text);
      }
    }),
  );

  void _calculateEstimatedCostFromHours(String? hoursValue) {
    final estimatedHours = FixedEx.tryParse(hoursValue);
    final estimatedCost = widget.hourlyRate.multiplyByFixed(estimatedHours);
    _estimatedLabourCostController.text = estimatedCost.toString();
  }

  @override
  Future<TaskItem> forUpdate(TaskItem taskItem) async => taskItem.copyWith(
    description: _descriptionController.text,
    purpose: _purposeController.text,
    itemType: June.getState(SelectedCheckListItemType.new).selected,
    estimatedMaterialUnitCost: MoneyEx.tryParse(
      _estimatedMaterialUnitCostController.text,
    ),
    estimatedMaterialQuantity: FixedEx.tryParse(
      _estimatedMaterialQuantityController.text,
    ),
    estimatedLabourHours: FixedEx.tryParse(
      _estimatedLabourHoursController.text,
    ),
    estimatedLabourCost: MoneyEx.tryParse(_estimatedLabourCostController.text),
    totalLineCharge: _chargeMode == ChargeMode.userDefined
        ? Money.tryParse(_chargeController.text, isoCode: 'AUD')
        : null,
    margin: Percentage.tryParse(_marginController.text) ?? Percentage.zero,
    billed: false,
    labourEntryMode: _labourEntryMode,
    measurementType: June.getState(
      SelectedMeasurementType.new,
    ).selectedOrDefault,
    dimension1:
        Fixed.tryParse(_dimension1Controller.text, decimalDigits: 3) ??
        Fixed.zero,
    dimension2:
        Fixed.tryParse(_dimension2Controller.text, decimalDigits: 3) ??
        Fixed.zero,
    dimension3:
        Fixed.tryParse(_dimension3Controller.text, decimalDigits: 3) ??
        Fixed.zero,
    units: June.getState(SelectedUnits.new).selectedOrDefault,
    url: _urlController.text,
    supplierId: June.getState(SelectedSupplier.new).selected,
  );

  @override
  Future<TaskItem> forInsert() async => TaskItem.forInsert(
    taskId: widget.parent!.id,
    description: _descriptionController.text,
    purpose: _purposeController.text,
    itemType: June.getState(SelectedCheckListItemType.new).selected!,
    estimatedMaterialUnitCost: MoneyEx.tryParse(
      _estimatedMaterialUnitCostController.text,
    ),
    estimatedMaterialQuantity: FixedEx.tryParse(
      _estimatedMaterialQuantityController.text,
    ),
    estimatedLabourHours: FixedEx.tryParse(
      _estimatedLabourHoursController.text,
    ),
    estimatedLabourCost: MoneyEx.tryParse(_estimatedLabourCostController.text),
    chargeMode: _chargeMode,
    totalLineCharge: _chargeMode == ChargeMode.userDefined
        ? Money.tryParse(_chargeController.text, isoCode: 'AUD')
        : null,
    margin: Percentage.tryParse(_marginController.text) ?? Percentage.zero,
    labourEntryMode: _labourEntryMode,
    measurementType: June.getState(
      SelectedMeasurementType.new,
    ).selectedOrDefault,
    dimension1:
        Fixed.tryParse(_dimension1Controller.text, decimalDigits: 3) ??
        Fixed.zero,
    dimension2:
        Fixed.tryParse(_dimension2Controller.text, decimalDigits: 3) ??
        Fixed.zero,
    dimension3:
        Fixed.tryParse(_dimension3Controller.text, decimalDigits: 3) ??
        Fixed.zero,
    units: June.getState(SelectedUnits.new).selectedOrDefault,
    url: _urlController.text,
    supplierId: June.getState(SelectedSupplier.new).selected,
  );

  @override
  void refresh() {
    setState(() {});
  }

  @override
  Future<void> postSave(Transaction transaction, Operation operation) async {}
}

class SelectedCheckListItemType extends JuneState {
  TaskItemType? _selected;

  set selected(TaskItemType? value) {
    _selected = value;
    setState();
  }

  TaskItemType? get selected => _selected;
}
