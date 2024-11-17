import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../../../dao/dao_checklist_item.dart';
import '../../../entity/check_list.dart';
import '../../../entity/check_list_item.dart';
import '../../../entity/check_list_item_type.dart';
import '../../../util/measurement_type.dart';
import '../../../util/money_ex.dart';
import '../../../util/percentage.dart';
import '../../../util/units.dart';
import '../../../widgets/fields/hmb_text_field.dart';
import '../../../widgets/select/hmb_droplist.dart';
import '../../base_nested/edit_nested_screen.dart';

class CheckListItemEditScreen extends StatefulWidget {
  const CheckListItemEditScreen(
      {super.key, this.checkListItem, this.checkList});

  final CheckListItem? checkListItem;
  final CheckList? checkList;

  @override
  _CheckListItemEditScreenState createState() =>
      _CheckListItemEditScreenState();
}

class _CheckListItemEditScreenState extends State<CheckListItemEditScreen>
    implements NestedEntityState<CheckListItem> {
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  late TextEditingController _unitCostController;
  late TextEditingController _labourHoursController;
  late TextEditingController _labourCostController;
  late TextEditingController _marginController;

  CheckListItemTypeEnum _selectedItemType = CheckListItemTypeEnum.materialsBuy;

  @override
  CheckListItem? currentEntity;

  @override
  void initState() {
    super.initState();
    currentEntity = widget.checkListItem;

    _descriptionController =
        TextEditingController(text: currentEntity?.description ?? '');
    _quantityController = TextEditingController(
        text: currentEntity?.estimatedMaterialQuantity?.toString() ?? '');
    _unitCostController = TextEditingController(
        text: currentEntity?.estimatedMaterialUnitCost?.toString() ?? '');
    _labourHoursController = TextEditingController(
        text: currentEntity?.estimatedLabourHours?.toString() ?? '');
    _labourCostController = TextEditingController(
        text: currentEntity?.estimatedLabourCost?.toString() ?? '');
    _marginController =
        TextEditingController(text: currentEntity?.margin.toString() ?? '0');

    _selectedItemType = currentEntity != null
        ? CheckListItemTypeEnum.fromId(currentEntity!.itemTypeId)
        : CheckListItemTypeEnum.materialsBuy;
  }

  @override
  Widget build(BuildContext context) =>
      NestedEntityEditScreen<CheckListItem, CheckList>(
        entityName: 'Item',
        dao: DaoCheckListItem(),
        entityState: this,
        onInsert: (item) async {
          await DaoCheckListItem().insertForCheckList(item!, widget.checkList!);
        },
        editor: (item) => SingleChildScrollView(
          child: Column(
            children: [
              HMBDroplist<CheckListItemTypeEnum>(
                title: 'Item Type',
                items: (filter) async => CheckListItemTypeEnum.values,
                selectedItem: () async => _selectedItemType,
                onChanged: (type) => setState(() {
                  _selectedItemType = type!;
                }),
                format: (value) => value.name,
              ),
              HMBTextField(
                controller: _descriptionController,
                labelText: 'Description',
                required: true,
              ),
              if (_selectedItemType != CheckListItemTypeEnum.labour) ...[
                HMBTextField(
                  controller: _quantityController,
                  labelText: 'Quantity',
                  keyboardType: TextInputType.number,
                ),
                HMBTextField(
                  controller: _unitCostController,
                  labelText: 'Unit Cost',
                  keyboardType: TextInputType.number,
                ),
              ],
              if (_selectedItemType == CheckListItemTypeEnum.labour) ...[
                HMBTextField(
                  controller: _labourHoursController,
                  labelText: 'Labour Hours',
                  keyboardType: TextInputType.number,
                ),
                HMBTextField(
                  controller: _labourCostController,
                  labelText: 'Labour Cost per Hour',
                  keyboardType: TextInputType.number,
                ),
              ],
              HMBTextField(
                controller: _marginController,
                labelText: 'Margin (%)',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      );

  @override
  Future<CheckListItem> forInsert() async => _buildCheckListItem();

  @override
  Future<CheckListItem> forUpdate(CheckListItem item) async =>
      _buildCheckListItem(id: item.id);

  CheckListItem _buildCheckListItem({int? id}) {
    final description = _descriptionController.text;
    final quantity = Fixed.parse(
        _quantityController.text.isEmpty ? '0' : _quantityController.text);
    final unitCost = MoneyEx.tryParse(_unitCostController.text);
    final labourHours = Fixed.parse(_labourHoursController.text.isEmpty
        ? '0'
        : _labourHoursController.text);
    final labourCost = MoneyEx.tryParse(_labourCostController.text);
    final margin = Percentage.tryParse(
        _marginController.text.isEmpty ? '0' : _marginController.text);

    return CheckListItem(
      id: id ?? 0,
      checkListId: widget.checkList!.id,
      description: description,
      itemTypeId: _selectedItemType.id,
      estimatedMaterialQuantity: quantity,
      estimatedMaterialUnitCost: unitCost,
      estimatedLabourHours: labourHours,
      estimatedLabourCost: labourCost,
      margin: margin,
      completed: false,
      charge: MoneyEx.zero,
      billed: false,
      createdDate: DateTime.now(),
      modifiedDate: DateTime.now(),
      measurementType: MeasurementType.defaultMeasurementType,
      dimension1: Fixed.zero,
      dimension2: Fixed.zero,
      dimension3: Fixed.zero,
      units: Units.defaultUnits,
      url: '',
      labourEntryMode: LabourEntryMode.hours,
    );
  }

  @override
  void refresh() {
    setState(() {});
  }
}
