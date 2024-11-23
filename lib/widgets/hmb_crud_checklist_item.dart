// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

import '../crud/check_list/list_task_item_screen.dart';
import '../entity/task.dart';
import 'hmb_child_crud_card.dart';

class HMBCrudTaskItem extends StatelessWidget {
  const HMBCrudTaskItem({
    required this.task,
    super.key,
  });

  final Task? task;

  @override
  Widget build(BuildContext context) => HMBChildCrudCard(
      headline: 'Items', crudListScreen: TaskItemListScreen(task: task));
}
