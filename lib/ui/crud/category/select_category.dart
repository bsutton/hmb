/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao_category.dart';
import '../../../entity/category.dart';
import '../../widgets/hmb_add_button.dart';
import '../../widgets/select/hmb_droplist.dart';
import 'edit_category_screen.dart';

class SelectCategory extends StatefulWidget {
  const SelectCategory({
    required this.selectedCategory,
    super.key,
    this.onSelected,
  });
  final SelectedCategory selectedCategory;

  final void Function(Category? category)? onSelected;

  @override
  SelectCategoryState createState() => SelectCategoryState();
}

class SelectCategoryState extends State<SelectCategory> {
  Future<Category?> _getInitialCategory() =>
      DaoCategory().getById(widget.selectedCategory.categoryId);

  Future<List<Category>> _getCategories(String? filter) =>
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
        builder: (context) => const CategoryEditScreen(),
      ),
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
          items: _getCategories,
          format: (category) => category.name,
        ),
      ),
      Center(child: HMBButtonAdd(enabled: true, onAdd: _addCategory)),
    ],
  );
}

class SelectedCategory extends JuneState {
  SelectedCategory();

  int? categoryId;
}
