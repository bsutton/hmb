import 'package:flutter/material.dart';

import '../../../dao/dao_category.dart';
import '../../../entity/category.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../base_full_screen/edit_entity_screen.dart';

class CategoryEditScreen extends StatefulWidget {
  const CategoryEditScreen({super.key, this.category});
  final Category? category;

  @override
  _CategoryEditScreenState createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends State<CategoryEditScreen>
    implements EntityState<Category> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  Category? currentEntity;

  @override
  void initState() {
    super.initState();
    currentEntity ??= widget.category;

    _nameController = TextEditingController(text: currentEntity?.name);
    _descriptionController =
        TextEditingController(text: currentEntity?.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EntityEditScreen<Category>(
        entityName: 'Category',
        dao: DaoCategory(),
        entityState: this,
        editor: (category) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HMBTextField(
              controller: _nameController,
              labelText: 'Name',
              required: true,
            ),
            HMBTextArea(
              controller: _descriptionController,
              labelText: 'Description',
            ),
          ],
        ),
      );

  @override
  Future<Category> forUpdate(Category category) async => Category.forUpdate(
        entity: category,
        name: _nameController.text,
        description: _descriptionController.text,
      );

  @override
  Future<Category> forInsert() async => Category.forInsert(
        name: _nameController.text,
        description: _descriptionController.text,
      );

  @override
  void refresh() {
    setState(() {});
  }
}
