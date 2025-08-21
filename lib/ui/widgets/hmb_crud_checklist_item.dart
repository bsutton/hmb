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

// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

import '../../entity/task.dart';
import '../crud/check_list/list_task_item_screen.dart';
import 'hmb_child_crud_card.dart';

class HMBCrudTaskItem extends StatelessWidget {
  final Task? task;
  
  const HMBCrudTaskItem({required this.task, super.key});


  @override
  Widget build(BuildContext context) => HMBChildCrudCard(
    headline: 'Items',
    crudListScreen: TaskItemListScreen(task: task),
  );
}
