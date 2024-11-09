import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_tool.dart';
import '../../entity/tool.dart';
import '../../util/money_ex.dart';
import '../../widgets/async_state.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/select/select_manufacture.dart';
import '../../widgets/select/select_supplier.dart';
import '../base_full_screen/edit_entity_screen.dart';
import '../category/select_category.dart';
import '../task/photo_crud.dart';

class ToolEditScreen extends StatefulWidget {
  const ToolEditScreen({super.key, this.tool});
  final Tool? tool;

  @override
  _ToolEditScreenState createState() => _ToolEditScreenState();
}

class _ToolEditScreenState extends AsyncState<ToolEditScreen, void>
    implements EntityState<Tool> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _serialNumberController;
  late TextEditingController _warrantyPeriodController;
  late TextEditingController _costController;
  late TextEditingController _receiptPhotoController;
  late TextEditingController _serialNumberPhotoController;
  late PhotoController<Tool> _photoController;

  @override
  Tool? currentEntity;
  final selectedSupplier = SelectedSupplier();
  final selectedManufacturer = SelectedManufacturer();
  final selectedCategory = SelectedCategory();

  @override
  Future<void> asyncInitState() async {
    currentEntity ??= widget.tool;

    _nameController = TextEditingController(text: currentEntity?.name);

    _descriptionController =
        TextEditingController(text: currentEntity?.description);
    _serialNumberController =
        TextEditingController(text: currentEntity?.serialNumber);
    _warrantyPeriodController =
        TextEditingController(text: currentEntity?.warrantyPeriod?.toString());
    _costController =
        TextEditingController(text: currentEntity?.cost?.toString());
    _receiptPhotoController =
        TextEditingController(text: currentEntity?.receiptPhotoPath);
    _serialNumberPhotoController =
        TextEditingController(text: currentEntity?.serialNumberPhotoPath);
    _photoController = PhotoController<Tool>(parent: currentEntity);

    if (currentEntity != null) {
      selectedSupplier.selected = currentEntity?.supplierId;
      selectedManufacturer.manufacturerId = currentEntity?.manufacturerId;
      selectedCategory.categoryId = currentEntity?.categoryId;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
      future: initialised,
      builder: (context, _) => EntityEditScreen<Tool>(
            entityName: 'Tool',
            dao: DaoTool(),
            entityState: this,
            editor: (tool) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HMBTextField(
                  controller: _nameController,
                  labelText: 'Name',
                  required: true,
                ),
                SelectCategory(
                  selectedCategory: selectedCategory,
                  onSelected: (category) {
                    setState(() {
                      selectedCategory.categoryId = category?.id;
                    });
                  },
                ),
                HMBTextArea(
                  controller: _descriptionController,
                  labelText: 'Description',
                ),
                SelectSupplier(
                  selectedSupplier: selectedSupplier,
                  onSelected: (supplier) {
                    setState(() {
                      selectedSupplier.selected = supplier?.id;
                    });
                  },
                ),
                SelectManufacturer(
                  selectedManufacturer: selectedManufacturer,
                  onSelected: (manufacturer) {
                    setState(() {
                      selectedManufacturer.manufacturerId = manufacturer?.id;
                    });
                  },
                ),
                HMBTextField(
                  controller: _serialNumberController,
                  labelText: 'Serial Number',
                ),
                HMBTextField(
                  controller: _warrantyPeriodController,
                  labelText: 'Warranty Period (months)',
                  keyboardType: TextInputType.number,
                ),
                HMBTextField(
                  controller: _costController,
                  labelText: 'Cost',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                HMBTextField(
                  controller: _receiptPhotoController,
                  labelText: 'Receipt Photo Path',
                ),
                HMBTextField(
                  controller: _serialNumberPhotoController,
                  labelText: 'Serial Number Photo Path',
                ),
                PhotoCrud<Tool>(
                    parentName: 'Tool', controller: _photoController),
              ],
            ),
          ));

  @override
  Future<Tool> forUpdate(Tool tool) async {
    await _photoController.save();
    return Tool.forUpdate(
      entity: tool,
      name: _nameController.text,
      categoryId: selectedCategory.categoryId,
      description: _descriptionController.text,
      serialNumber: _serialNumberController.text,
      supplierId: selectedSupplier.selected,
      manufacturerId: selectedManufacturer.manufacturerId,
      warrantyPeriod: int.tryParse(_warrantyPeriodController.text),
      cost: MoneyEx.tryParse(_costController.text),
      receiptPhotoPath: _receiptPhotoController.text,
      serialNumberPhotoPath: _serialNumberPhotoController.text,
    );
  }

  @override
  Future<Tool> forInsert() async => Tool.forInsert(
        name: _nameController.text,
        categoryId: selectedCategory.categoryId,
        description: _descriptionController.text,
        serialNumber: _serialNumberController.text,
        supplierId: selectedSupplier.selected,
        manufacturerId: selectedManufacturer.manufacturerId,
        warrantyPeriod: int.tryParse(_warrantyPeriodController.text),
        cost: MoneyEx.tryParse(_costController.text),
        receiptPhotoPath: _receiptPhotoController.text,
        serialNumberPhotoPath: _serialNumberPhotoController.text,
      );

  @override
  void refresh() {
    setState(() {});
  }
}
