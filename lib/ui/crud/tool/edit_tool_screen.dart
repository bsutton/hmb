import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao_photo.dart';
import '../../../dao/dao_tool.dart';
import '../../../entity/_index.g.dart';
import '../../../entity/tool.dart';
import '../../../util/money_ex.dart';
import '../../../util/photo_meta.dart';
import '../../widgets/async_state.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/grayed_out.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_date_time_picker.dart';
import '../../widgets/media/captured_photo.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/media/photo_thumbnail.dart';
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

class _ToolEditScreenState extends AsyncState<ToolEditScreen>
    implements EntityState<Tool> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _serialNumberController;
  late TextEditingController _warrantyPeriodController;
  late TextEditingController _costController;
  late PhotoController<Tool> _photoController;

  int? _receiptPhotoId;
  int? _serialNumberPhotoId;

  @override
  Tool? currentEntity;
  final selectedSupplier = SelectedSupplier();
  final selectedManufacturer = SelectedManufacturer();
  final selectedCategory = SelectedCategory();
  DateTime selectedDatePurchased = DateTime.now();

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
    selectedDatePurchased = currentEntity?.datePurchased ?? DateTime.now();
    _photoController = PhotoController<Tool>(
        parent: currentEntity,
        parentType: ParentType.tool,
        filter: (tool, photo) => !(photo.id == tool.serialNumberPhotoId ||
            photo.id == tool.receiptPhotoId));

    _receiptPhotoId = currentEntity?.receiptPhotoId;
    _serialNumberPhotoId = currentEntity?.serialNumberPhotoId;

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
            editor: (tool, {required isNew}) => Column(
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
                HMBDateTimeField(
                  mode: HMBDateTimeFieldMode.dateOnly,
                  label: 'Date Purchased',
                  initialDateTime: selectedDatePurchased,
                  onChanged: (datePurchased) async {
                    selectedDatePurchased = datePurchased;
                  },
                ),
                const SizedBox(height: 16),
                _buildPhotoField(
                  enabled: !isNew,
                  context,
                  title: 'Serial Number Photo',
                  photoId: _serialNumberPhotoId,
                  onCapture: (capturedPhoto) async {
                    // Create a new Photo entity
                    final newPhoto = Photo.forInsert(
                      parentId: currentEntity?.id ?? 0,
                      parentType: 'tool',
                      filePath: capturedPhoto.relativePath,
                      comment: 'Serial Number Photo',
                    );

                    // Insert the photo into the DB
                    final photoId = await DaoPhoto().insert(newPhoto);

                    // Update the state
                    setState(() {
                      _serialNumberPhotoId = photoId;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildPhotoField(
                  context,
                  enabled: !isNew,
                  title: 'Receipt Photo',
                  photoId: _receiptPhotoId,
                  onCapture: (capturedPhoto) async {
                    // Create a new Photo entity
                    final newPhoto = Photo.forInsert(
                      parentId: currentEntity?.id ?? 0,
                      parentType: 'tool',
                      filePath: capturedPhoto.relativePath,
                      comment: 'Reciept Photo',
                    );

                    // Insert the photo into the DB
                    final photoId = await DaoPhoto().insert(newPhoto);

                    // Update the state
                    setState(() {
                      _receiptPhotoId = photoId;
                    });
                  },
                ),
                const SizedBox(height: 16),
                PhotoCrud<Tool>(
                  parentName: 'Tool',
                  parentType: ParentType.tool,
                  controller: _photoController,
                ),
              ],
            ),
          ));

  Widget _buildPhotoField(BuildContext context,
          {required String title,
          required bool enabled,
          required int? photoId,
          required void Function(CapturedPhoto) onCapture}) =>
      GrayedOut(
        grayedOut: !enabled,
        child: FutureBuilderEx(
            // ignore: discarded_futures
            future: _getPhotoMeta(photoId),
            builder: (context, photoMeta) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        HMBButton.withIcon(
                          label: 'Capture Photo',
                          icon: const Icon(Icons.camera_alt),
                          onPressed: () async {
                            final capturedPhoto =
                                await _photoController.takePhoto();
                            if (capturedPhoto != null) {
                              onCapture(capturedPhoto);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (photoMeta != null)
                      PhotoThumbnail(
                          photoPath: photoMeta.absolutePathTo, title: title)
                  ],
                )),
      );

  Future<PhotoMeta?> _getPhotoMeta(int? photoId) async {
    final photo = await DaoPhoto().getById(photoId);

    if (photo != null) {
      final meta = PhotoMeta.fromPhoto(photo: photo);
      await meta.resolve();
      return meta;
    } else {
      return null;
    }
  }

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
      receiptPhotoId: _receiptPhotoId,
      serialNumberPhotoId: _serialNumberPhotoId,
      datePurchased: selectedDatePurchased,
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
        receiptPhotoId: _receiptPhotoId,
        serialNumberPhotoId: _serialNumberPhotoId,
        datePurchased: selectedDatePurchased,
      );

  @override
  void refresh() {
    setState(() {});
  }
}
