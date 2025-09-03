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
    // ignore: discarded_futures
    fetchList: (filter) => DaoCategory().getByFilter(filter),
    onEdit: (category) => CategoryEditScreen(category: category),
    listCard: (entity) => HMBTextBody(entity.description ?? ''),
  );
}
