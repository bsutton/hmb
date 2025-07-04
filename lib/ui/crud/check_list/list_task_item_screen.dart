/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:money2/money2.dart';

import '../../../dao/dao_task.dart';
import '../../../dao/dao_task_item.dart';
import '../../../entity/entity.dart';
import '../../../entity/job.dart';
import '../../../entity/task.dart';
import '../../../entity/task_item.dart';
import '../../../util/money_ex.dart';
import '../../task_items/task_items.g.dart';
import '../../widgets/hmb_toggle.dart';
import '../../widgets/text/hmb_text.dart';
import '../base_nested/list_nested_screen.dart';
import 'edit_task_item_screen.dart';

class TaskItemListScreen extends StatefulWidget {
  const TaskItemListScreen({required this.task, super.key});

  final Task? task;

  // final Parent<Task> parent;

  // final DaoJoinAdaptor<CheckListItem, Task> daoJoin;
  // final TaskItemType? checkListItemType;

  @override
  State<TaskItemListScreen> createState() => _TaskItemListScreenState<Task>();
}

class TaskAndRate {
  TaskAndRate(this.task, this.rate, this.billingType);
  Task? task;
  Money rate;
  BillingType billingType;

  static Future<TaskAndRate> fromTask(Task task) async {
    final hourlyRate = await DaoTask().getHourlyRate(task);
    final billingType = await DaoTask().getBillingType(task);
    return TaskAndRate(task, hourlyRate, billingType);
  }
}

Future<TaskAndRate> getTaskAndRate(Task? task) async {
  if (task == null) {
    return TaskAndRate(null, MoneyEx.zero, BillingType.timeAndMaterial);
  }
  return TaskAndRate.fromTask(task);
}

class _TaskItemListScreenState<P extends Entity<P>>
    extends State<TaskItemListScreen> {
  @override
  Widget build(BuildContext context) {
    final showCompleted = June.getState(
      ShowCompltedItems.new,
    )._showCompletedTasks;

    return FutureBuilderEx(
      // ignore: discarded_futures
      future: getTaskAndRate(widget.task),
      builder: (context, taskAndRate) => NestedEntityListScreen<TaskItem, Task>(
        key: ValueKey(showCompleted),
        parent: Parent(widget.task), // widget.parent,
        parentTitle: 'Task',
        entityNameSingular: 'Task Item',
        entityNamePlural: 'Task Items',
        dao: DaoTaskItem(),
        // ignore: discarded_futures
        onDelete: (taskItem) => DaoTaskItem().delete(taskItem.id),
        // ignore: discarded_futures
        onInsert: (taskItem, transaction) =>
            DaoTaskItem().insert(taskItem, transaction),
        // ignore: discarded_futures
        fetchList: () => _fetchItems(showCompleted),
        title: (taskItem) => Text(taskItem.description) as Widget,
        onEdit: (taskItem) => TaskItemEditScreen(
          parent: widget.task,
          taskItem: taskItem,
          billingType: taskAndRate?.billingType ?? BillingType.timeAndMaterial,
          hourlyRate: taskAndRate?.rate ?? MoneyEx.zero,
        ),
        details: (entity, details) {
          final taskItem = entity;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._buildFieldsBasedOnItemType(
                taskItem,
                taskAndRate!.billingType,
                taskAndRate.rate,
              ),
              HMBText(taskItem.dimensions),
              if (taskItem.completed)
                const Text('Completed', style: TextStyle(color: Colors.green))
              else
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => unawaited(
                    markAsCompleted(
                      TaskItemContext(
                        task: widget.task!,
                        taskItem: taskItem,
                        billingType: taskAndRate.billingType,
                        wasReturned: false,
                      ),
                      context,
                    ),
                  ),
                ),
            ],
          );
        },
        filterBar: (entity) => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            HMBToggle(
              label: 'Show Completed',
              tooltip: showCompleted
                  ? 'Show Only Non-Completed Tasks'
                  : 'Show Completed Tasks',
              initialValue: June.getState(
                ShowCompltedItems.new,
              )._showCompletedTasks,
              onToggled: (value) {
                setState(() {
                  June.getState(ShowCompltedItems.new).toggle();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<TaskItem>> _fetchItems(bool showCompleted) async {
    final items = await DaoTaskItem().getByTask(widget.task!.id);

    return items
        .where((item) => showCompleted ? item.completed : !item.completed)
        .toList();
  }

  List<Widget> _buildFieldsBasedOnItemType(
    TaskItem taskItem,
    BillingType billingType,
    Money hourlyRate,
  ) {
    switch (taskItem.itemTypeId) {
      case 5: // Labour
        return _buildLabourFields(taskItem, billingType, hourlyRate);
      case 1: // Materials - buy
      case 3: // Tools - buy
        return _buildBuyFields(taskItem, billingType, hourlyRate);
      case 2: // Materials - stock
      case 4: // Tools - stock
        return _buildStockFields(taskItem, billingType, hourlyRate);
      default:
        return [];
    }
  }

  List<Widget> _buildLabourFields(
    TaskItem checkListItem,
    BillingType billingType,
    Money hourlyRate,
  ) => [
    if (checkListItem.labourEntryMode == LabourEntryMode.hours)
      HMBText(
        'Est: Hours: ${checkListItem.estimatedLabourHours} '
        'Cost: ${checkListItem.estimatedLabourCost} ',
      ),
    HMBText(
      'Charge: ${checkListItem.getCharge(billingType, hourlyRate)} '
      'Margin (%): ${checkListItem.margin}',
    ),
  ];

  List<Widget> _buildBuyFields(
    TaskItem checkListItem,
    BillingType billingType,
    Money hourlyRate,
  ) => [
    HMBText(
      'Est: Unit Cost: ${checkListItem.estimatedMaterialUnitCost} '
      'Qty: ${checkListItem.estimatedMaterialQuantity} ',
    ),
    HMBText(
      'Margin (%): ${checkListItem.margin} '
      'Charge: ${checkListItem.getCharge(billingType, hourlyRate)}',
    ),
  ];

  List<Widget> _buildStockFields(
    TaskItem checkListItem,
    BillingType billingType,
    Money hourlyRate,
  ) => [
    HMBText(
      'Unit Charge: ${checkListItem.estimatedMaterialUnitCost} '
      'Qty: ${checkListItem.estimatedMaterialQuantity} ',
    ),
    HMBText(
      'Margin (%): ${checkListItem.margin} '
      'Charge: ${checkListItem.getCharge(billingType, hourlyRate)}',
    ),
  ];
}

class ShowCompltedItems extends JuneState {
  var _showCompletedTasks = false;

  void toggle() {
    _showCompletedTasks = !_showCompletedTasks;
    setState(); // Notify listeners to rebuild
  }
}
