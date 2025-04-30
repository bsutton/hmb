import 'package:flutter/material.dart';

import '../../../dao/dao_category.dart';
import '../../../entity/category.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_category_screen.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) => EntityListScreen<Category>(
    pageTitle: 'Categories',
    dao: DaoCategory(),
    title: (entity) => HMBTextHeadline2(entity.name),
    fetchList: (filter) => DaoCategory().getByFilter(filter),
    onEdit: (category) => CategoryEditScreen(category: category),
    details: (entity) => HMBTextBody(entity.description ?? ''),
  );
}
