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
import '../../util/money_ex.dart';
import '../../util/platform_ex.dart';
import '../../widgets/hmb_droplist.dart';
import '../../widgets/hmb_text_field.dart';
import '../base_nested/nested_edit_screen.dart';
import 'dimension_type.dart';
import 'dimension_units.dart';

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
  DimensionType _selectedDimensionType = DimensionType.length;
  String _selectedUnit = metricUnits[DimensionType.length]!.first;
  late System system;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.checkListItem?.description);
    _costController =
        TextEditingController(text: widget.checkListItem?.unitCost.toString());
    _quantityController =
        TextEditingController(text: widget.checkListItem?.quantity.toString());
    _effortInHoursController = TextEditingController(
        text: widget.checkListItem?.effortInHours.toString());
    _dimension1Controller = TextEditingController(
        text: widget.checkListItem?.dimension1.toString());
    _dimension2Controller = TextEditingController(
        text: widget.checkListItem?.dimension2.toString());
    _dimension3Controller = TextEditingController(
        text: widget.checkListItem?.dimension3.toString());

    _descriptionFocusNode = FocusNode();
  }

  // Future<void> _initializeSystemSettings() async {
  //   system = (await DaoSystem().get())!;
  //   _selectedUnit = system.useMetricUnits
  //       ? metricUnits[_selectedDimensionType]!.first
  //       : imperialUnits[_selectedDimensionType]!.first;
  //   setState(() {});
  // }

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
  Widget build(BuildContext context) =>
      NestedEntityEditScreen<CheckListItem, CheckList>(
        entity: widget.checkListItem,
        entityName: 'Check List Item',
        dao: DaoCheckListItem(),
        onInsert: (checkListItem) async =>
            widget.daoJoin.insertForParent(checkListItem!, widget.parent),
        entityState: this,
        editor: (checklistItem) {
          _selectedDimensionType =
              checklistItem?.dimensionType ?? DimensionType.length;
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

              /// Units
              FutureBuilderEx<System?>(
                // ignore: discarded_futures
                future: DaoSystem().get(),
                waitingBuilder: (_) => HMBDroplist.placeHolder(),
                builder: (context, system) => HMBDroplist<String>(
                    title: 'Units',
                    initialItem: () async => _selectedUnit,
                    format: (unit) => unit,
                    items: (filter) async =>
                        system!.preferredUnits == PreferredUnits.metric
                            ? metricUnits[_selectedDimensionType]!
                            : imperialUnits[_selectedDimensionType]!,
                    onChanged: (value) {
                      setState(() {
                        _selectedUnit = value;
                      });
                    }),
              ),

              /// Dimensions
              FutureBuilderEx<System?>(
                // ignore: discarded_futures
                future: DaoSystem().get(),
                waitingBuilder: (_) => HMBDroplist.placeHolder(),
                builder: (context, system) => HMBDroplist<DimensionType>(
                  title: 'Dimensions',
                  initialItem: () async => _selectedDimensionType,
                  format: (type) => type.name,
                  items: (filter) async => DimensionType.values,
                  onChanged: (value) {
                    setState(() {
                      _selectedDimensionType = value;
                    });
                  },
                ),
              ),
              if (_selectedDimensionType.labels.isNotEmpty)
                HMBTextField(
                  controller: _dimension1Controller,
                  labelText: _selectedDimensionType.labels[0],
                  keyboardType: TextInputType.number,
                ),
              if (_selectedDimensionType.labels.length > 1)
                HMBTextField(
                  controller: _dimension2Controller,
                  labelText: _selectedDimensionType.labels[1],
                  keyboardType: TextInputType.number,
                ),
              if (_selectedDimensionType.labels.length > 2)
                HMBTextField(
                  controller: _dimension3Controller,
                  labelText: _selectedDimensionType.labels[2],
                  keyboardType: TextInputType.number,
                ),
            ],
          );
        },
      );

  HMBDroplist<CheckListItemType> _chooseItemType(
          CheckListItem? checkListItem) =>
      HMBDroplist<CheckListItemType>(
        title: 'Item Type',
        initialItem: () async =>
            DaoCheckListItemType().getById(checkListItem?.itemTypeId),
        items: (filter) async => DaoCheckListItemType().getByFilter(filter),
        format: (taskStatus) => taskStatus.name,
        onChanged: (item) =>
            June.getState(CheckListItemTypeStatus.new).checkListItemType = item,
      );

  @override
  Future<CheckListItem> forUpdate(CheckListItem checkListItem) async =>
      CheckListItem.forUpdate(
          entity: checkListItem,
          checkListId: checkListItem.checkListId,
          description: _descriptionController.text,
          itemTypeId: June.getState(CheckListItemTypeStatus.new)
                  .checkListItemType
                  ?.id ??
              0,
          billed: false,
          unitCost: MoneyEx.tryParse(_costController.text),
          quantity: FixedEx.tryParse(_quantityController.text),
          effortInHours: FixedEx.tryParse(_effortInHoursController.text),
          completed: checkListItem.completed,
          dimensionType: _selectedDimensionType,
          dimension1: Fixed.tryParse(_dimension1Controller.text) ?? Fixed.zero,
          dimension2: Fixed.tryParse(_dimension2Controller.text) ?? Fixed.zero,
          dimension3: Fixed.tryParse(_dimension3Controller.text) ?? Fixed.zero);

  @override
  Future<CheckListItem> forInsert() async => CheckListItem.forInsert(
        checkListId: widget.parent.id,
        description: _descriptionController.text,
        itemTypeId:
            June.getState(CheckListItemTypeStatus.new).checkListItemType?.id ??
                0,
        unitCost: MoneyEx.tryParse(_costController.text),
        quantity: FixedEx.tryParse(_quantityController.text),
        effortInHours: FixedEx.tryParse(_effortInHoursController.text),
        dimensionType: _selectedDimensionType,
        dimension1: Fixed.tryParse(_dimension1Controller.text) ?? Fixed.zero,
        dimension2: Fixed.tryParse(_dimension2Controller.text) ?? Fixed.zero,
        dimension3: Fixed.tryParse(_dimension3Controller.text) ?? Fixed.zero,
      );

  @override
  void refresh() {
    setState(() {});
  }
}

class CheckListItemTypeStatus {
  CheckListItemType? checkListItemType;
}
