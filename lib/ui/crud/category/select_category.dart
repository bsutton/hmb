import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao_category.dart';
import '../../../entity/category.dart';
import '../../widgets/hmb_add_button.dart';
import '../../widgets/select/hmb_droplist.dart';
import 'edit_category_screen.dart';

class SelectCategory extends StatefulWidget {
  const SelectCategory(
      {required this.selectedCategory, super.key, this.onSelected});
  final SelectedCategory selectedCategory;

  final void Function(Category? category)? onSelected;

  @override
  SelectCategoryState createState() => SelectCategoryState();
}

class SelectCategoryState extends State<SelectCategory> {
  Future<Category?> _getInitialCategory() async =>
      DaoCategory().getById(widget.selectedCategory.categoryId);

  Future<List<Category>> _getCategories(String? filter) async =>
      DaoCategory().getByFilter(filter);

  void _onCategoryChanged(Category? newValue) {
    setState(() {
      widget.selectedCategory.categoryId = newValue?.id;
    });
    widget.onSelected?.call(newValue);
  }

  Future<void> _addCategory() async {
    final category = await Navigator.push<Category>(
      context,
      MaterialPageRoute<Category>(
          builder: (context) => const CategoryEditScreen()),
    );
    if (category != null) {
      setState(() {
        widget.selectedCategory.categoryId = category.id;
      });
      widget.onSelected?.call(category);
    }
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: HMBDroplist<Category>(
              title: 'Category',
              selectedItem: _getInitialCategory,
              onChanged: _onCategoryChanged,
              items: (filter) async => _getCategories(filter),
              format: (category) => category.name,
            ),
          ),
          Center(
            child: HMBButtonAdd(
              enabled: true,
              onPressed: _addCategory,
            ),
          ),
        ],
      );
}

class SelectedCategory extends JuneState {
  SelectedCategory();

  int? categoryId;
}