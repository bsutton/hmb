import 'package:fixed/fixed.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../dao/dao_check_list_item_type.dart';
import '../../dao/dao_checklist_item.dart';
import '../../dao/dao_system.dart';
import '../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../entity/check_list.dart';
import '../../entity/check_list_item.dart';
import '../../entity/check_list_item_type.dart';
import '../../entity/entity.dart';
import '../../entity/system.dart';
import '../../util/fixed_ex.dart';
import '../../util/measurement_type.dart';
import '../../util/money_ex.dart';
import '../../util/platform_ex.dart';
import '../../widgets/hmb_droplist.dart';
import '../../widgets/hmb_text_field.dart';
import '../base_nested/nested_edit_screen.dart';
import 'dimensions.dart';

class CheckListItemEditScreen<P extends Entity<P>> extends StatefulWidget {
  const CheckListItemEditScreen(
      {required this.parent,
      required this.daoJoin,
      super.key,
      this.checkListItem});
  final DaoJoinAdaptor daoJoin;
  final P parent;
  final CheckListItem? checkListItem;

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
  late TextEditingController _costController;
  late TextEditingController _quantityController;
  late TextEditingController _effortInHoursController;

  late TextEditingController _dimension1Controller;

  late TextEditingController _dimension2Controller;

  late TextEditingController _dimension3Controller;

  late FocusNode _descriptionFocusNode;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.checkListItem?.description);
    _costController =
        TextEditingController(text: widget.checkListItem?.unitCost.toString());
    _quantityController = TextEditingController(
        text: (widget.checkListItem?.quantity ?? Fixed.one).toString());
    _effortInHoursController = TextEditingController(
        text: widget.checkListItem?.effortInHours.toString());

    _dimension1Controller = TextEditingController(
        text: widget.checkListItem?.dimension1.toString());
    _dimension2Controller = TextEditingController(
        text: widget.checkListItem?.dimension2.toString());
    _dimension3Controller = TextEditingController(
        text: widget.checkListItem?.dimension3.toString());

    _descriptionFocusNode = FocusNode();

    June.getState(SelectedUnits.new).selected = null;
    June.getState(SelectedDimensionType.new).selected = null;
    June.getState(SelectedCheckListItemType.new).selected = null;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _costController.dispose();
    _quantityController.dispose();
    _effortInHoursController.dispose();

    _dimension1Controller.dispose();
    _dimension2Controller.dispose();
    _dimension3Controller.dispose();

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
                  HMBTextField(
                    controller: _costController,
                    labelText: 'Cost',
                    keyboardType: TextInputType.number,
                  ),
                  HMBTextField(
                    controller: _quantityController,
                    labelText: 'Quantity',
                    keyboardType: TextInputType.number,
                  ),
                  HMBTextField(
                    controller: _effortInHoursController,
                    labelText: 'Effort (in hours)',
                    keyboardType: TextInputType.number,
                  ),

                  /// Dimensions

                  DimensionWidget(
                    dimension1Controller: _dimension1Controller,
                    dimension2Controller: _dimension2Controller,
                    dimension3Controller: _dimension3Controller,
                    checkListItem: checklistItem,
                  )
                ],
              );
            },
          ));

  HMBDroplist<CheckListItemType> _chooseItemType(
          CheckListItem? checkListItem) =>
      HMBDroplist<CheckListItemType>(
        title: 'Item Type',
        initialItem: () async =>
            DaoCheckListItemType().getById(checkListItem?.itemTypeId),
        items: (filter) async => DaoCheckListItemType().getByFilter(filter),
        format: (checklistItemType) => checklistItemType.name,
        onChanged: (itemType) =>
            June.getState(SelectedCheckListItemType.new).selected = itemType.id,
      );

  @override
  Future<CheckListItem> forUpdate(CheckListItem checkListItem) async =>
      CheckListItem.forUpdate(
          entity: checkListItem,
          checkListId: checkListItem.checkListId,
          description: _descriptionController.text,
          itemTypeId:
              June.getState(SelectedCheckListItemType.new).selected ?? 0,
          billed: false,
          unitCost: MoneyEx.tryParse(_costController.text),
          quantity: FixedEx.tryParse(_quantityController.text),
          effortInHours: FixedEx.tryParse(_effortInHoursController.text),
          completed: checkListItem.completed,
          measurementType:
              June.getState(SelectedDimensionType.new).selectedOrDefault,
          dimension1: Fixed.tryParse(_dimension1Controller.text) ?? Fixed.zero,
          dimension2: Fixed.tryParse(_dimension2Controller.text) ?? Fixed.zero,
          dimension3: Fixed.tryParse(_dimension3Controller.text) ?? Fixed.zero,
          units:
              June.getState(SelectedUnits.new).selectedOrDefault); // Save units

  @override
  Future<CheckListItem> forInsert() async => CheckListItem.forInsert(
        checkListId: widget.parent.id,
        description: _descriptionController.text,
        itemTypeId: June.getState(SelectedCheckListItemType.new).selected ?? 0,
        unitCost: MoneyEx.tryParse(_costController.text),
        quantity: FixedEx.tryParse(_quantityController.text),
        effortInHours: FixedEx.tryParse(_effortInHoursController.text),
        measurementType:
            June.getState(SelectedDimensionType.new).selectedOrDefault,
        dimension1: Fixed.tryParse(_dimension1Controller.text) ?? Fixed.zero,
        dimension2: Fixed.tryParse(_dimension2Controller.text) ?? Fixed.zero,
        dimension3: Fixed.tryParse(_dimension3Controller.text) ?? Fixed.zero,
        units: June.getState(SelectedUnits.new).selectedOrDefault, // Save units
      );

  @override
  void refresh() {
    setState(() {});
  }

  void _initSelected(CheckListItem? checklistItem, System? system) {
    // ItemType
    June.getState(SelectedCheckListItemType.new).selected =
        checklistItem?.itemTypeId;

    /// Dimensions
    final selectedDimensionType = checklistItem?.measurementType ?? length;
    June.getState(SelectedDimensionType.new).selected = selectedDimensionType;

    /// units
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
  /// selected id of the [CheckListItemType].
  int? _selected;

  set selected(int? value) {
    _selected = value;

    setState();
  }

  int? get selected => _selected;
}
