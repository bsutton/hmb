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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_task.dart';
import '../../../dao/dao_task_item.dart';
import '../../../entity/entity.dart';
import '../../../entity/job.dart';
import '../../../entity/material_price.dart';
import '../../../entity/task.dart';
import '../../../entity/task_item.dart';
import '../../../entity/task_item_type.dart';
import '../../../util/dart/fixed_ex.dart';
import '../../../util/dart/money_ex.dart';
import '../../task_items/task_items.g.dart';
import '../../widgets/hmb_search.dart';
import '../../widgets/hmb_toggle.dart';
import '../../widgets/icons/hmb_complete_icon.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/text/hmb_text.dart';
import '../base_nested/list_nested_screen.dart';
import 'edit_task_item_screen.dart';

class TaskItemListScreen extends StatefulWidget {
  final Task? task;

  const TaskItemListScreen({required this.task, super.key});

  @override
  State<TaskItemListScreen> createState() => _TaskItemListScreenState<Task>();
}

class TaskAndRate {
  Task? task;
  Money rate;
  BillingType billingType;

  TaskAndRate(this.task, this.rate, this.billingType);

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
  late final Parent<Task> _parent;
  String? _filterText;

  @override
  void initState() {
    super.initState();
    _parent = Parent(widget.task);
  }

  @override
  void didUpdateWidget(covariant TaskItemListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task != widget.task) {
      _parent.parent = widget.task;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCompleted = June.getState(
      ShowCompltedItems.new,
    )._showCompletedTasks;

    return FutureBuilderEx(
      future: getTaskAndRate(widget.task),
      builder: (context, taskAndRate) => NestedEntityListScreen<TaskItem, Task>(
        key: ValueKey(showCompleted),
        parent: _parent,
        parentTitle: 'Task',
        entityNameSingular: 'Task Item',
        entityNamePlural: 'Task Items',
        dao: DaoTaskItem(),
        onDelete: (taskItem) => DaoTaskItem().delete(taskItem.id),
        fetchList: () => _fetchItems(showCompleted),
        title: (taskItem) => Text(taskItem.description) as Widget,
        onEdit: (taskItem) => TaskItemEditScreen(
          parent: _parent.parent,
          taskItem: taskItem,
          billingType: taskAndRate?.billingType ?? BillingType.timeAndMaterial,
          hourlyRate: taskAndRate?.rate ?? MoneyEx.zero,
        ),
        extended: true,
        details: (entity, details) {
          final taskItem = entity;
          return HMBColumn(
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
                HMBCompleteIcon(
                  onPressed: () => markAsCompleted(
                    TaskItemContext(
                      task: _parent.parent!,
                      taskItem: taskItem,
                      billingType: taskAndRate.billingType,
                      wasReturned: false,
                    ),
                    context,
                  ),
                ),
            ],
          );
        },
        filterBar: (entity) => HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 320,
              child: HMBSearch(
                onSearch: (filter) async {
                  setState(() {
                    _filterText = filter?.trim().toLowerCase();
                  });
                },
                label: 'Search Task Items',
              ),
            ),
            HMBToggle(
              label: 'Show Completed',
              hint: showCompleted
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
    final task = _parent.parent;
    if (task == null) {
      return const [];
    }
    final items = await DaoTaskItem().getByTask(task.id);
    final search = _filterText;

    return items.where((item) {
      final completionMatch = showCompleted ? item.completed : !item.completed;
      if (!completionMatch) {
        return false;
      }
      if (Strings.isBlank(search)) {
        return true;
      }
      final filter = search!;
      return item.description.toLowerCase().contains(filter) ||
          item.dimensions.toLowerCase().contains(filter) ||
          item.itemType.label.toLowerCase().contains(filter);
    }).toList();
  }

  List<Widget> _buildFieldsBasedOnItemType(
    TaskItem taskItem,
    BillingType billingType,
    Money hourlyRate,
  ) {
    switch (taskItem.itemType) {
      case TaskItemType.labour: // Labour
        return _buildLabourFields(taskItem, billingType, hourlyRate);
      case TaskItemType.materialsBuy: // Materials - buy
      case TaskItemType.toolsBuy: // Tools - buy
      case TaskItemType.toolsHire: // Tools - hire
      case TaskItemType.consumablesBuy:
        return _buildBuyFields(taskItem, billingType, hourlyRate);
      case TaskItemType.materialsStock: // Materials - stock
      case TaskItemType.toolsOwn: // Tools - stock
      case TaskItemType.consumablesStock:
        return _buildStockFields(taskItem, billingType, hourlyRate);
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
      'Charge: ${checkListItem.getTotalLineCharge(billingType, hourlyRate)} '
      'Margin (%): ${checkListItem.margin}',
    ),
  ];

  List<Widget> _buildBuyFields(
    TaskItem checkListItem,
    BillingType billingType,
    Money hourlyRate,
  ) => [
    TaskItemMaterialCostSummary(taskItem: checkListItem),
    HMBText(
      'Margin (%): ${checkListItem.margin} '
      'Charge: ${checkListItem.getTotalLineCharge(billingType, hourlyRate)}',
    ),
  ];

  List<Widget> _buildStockFields(
    TaskItem checkListItem,
    BillingType billingType,
    Money hourlyRate,
  ) => [
    TaskItemMaterialCostSummary(taskItem: checkListItem),
    HMBText(
      'Margin (%): ${checkListItem.margin} '
      'Charge: ${checkListItem.getTotalLineCharge(billingType, hourlyRate)}',
    ),
  ];
}

class TaskItemMaterialCostSummary extends StatelessWidget {
  final TaskItem taskItem;

  const TaskItemMaterialCostSummary({required this.taskItem, super.key});

  @override
  Widget build(BuildContext context) => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      HMBText(_priceLine('Est', taskItem.estimatedPrice)),
      if (taskItem.completed)
        HMBText(_priceLine('Actual', taskItem.actualPrice)),
    ],
  );

  String _priceLine(String label, MaterialPrice? price) {
    if (price == null) {
      return '$label: —';
    }
    if (price.isPackagePrice) {
      return '$label: Package Cost: ${price.unitCost} '
          'Packages: ${price.quantity.toInt()}';
    }
    return '$label: Unit Cost: ${price.unitCost} '
        'Qty: ${price.quantity.compact()}';
  }
}

class ShowCompltedItems extends JuneState {
  var _showCompletedTasks = false;

  void toggle() {
    _showCompletedTasks = !_showCompletedTasks;
    setState(); // Notify listeners to rebuild
  }
}
