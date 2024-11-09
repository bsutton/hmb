import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:money2/money2.dart';

import '../../dao/dao_checklist_item.dart';
import '../../dao/dao_task.dart';
import '../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../entity/check_list.dart';
import '../../entity/check_list_item.dart';
import '../../entity/check_list_item_type.dart';
import '../../entity/entity.dart';
import '../../entity/job.dart';
import '../../entity/task.dart';
import '../../util/money_ex.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_toggle.dart';
import '../../widgets/text/hmb_text.dart';
import '../base_nested/list_nested_screen.dart';
import 'edit_checklist_item_screen.dart';

class CheckListItemListScreen<P extends Entity<P>> extends StatefulWidget {
  const CheckListItemListScreen({
    required this.parent,
    required this.daoJoin,
    super.key,
    this.checkListItemType,
  });

  final Parent<P> parent;

  final DaoJoinAdaptor<CheckListItem, P> daoJoin;
  final CheckListItemType? checkListItemType;

  @override
  State<CheckListItemListScreen<P>> createState() =>
      _CheckListItemListScreenState<P>();
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

Future<TaskAndRate> getTaskAndRate(CheckList? checkList) async {
  if (checkList == null) {
    return TaskAndRate(null, MoneyEx.zero, BillingType.timeAndMaterial);
  }
  return TaskAndRate.fromTask(await DaoTask().getTaskForCheckList(checkList));
}

class _CheckListItemListScreenState<P extends Entity<P>>
    extends State<CheckListItemListScreen<P>> {
  @override
  Widget build(BuildContext context) {
    final showCompleted =
        June.getState(ShowCompltedItems.new).showCompletedTasks;

    return FutureBuilderEx(
      // ignore: discarded_futures
      future: getTaskAndRate(widget.parent.parent as CheckList?),
      builder: (context, taskAndRate) =>
          NestedEntityListScreen<CheckListItem, P>(
              key: ValueKey(showCompleted),
              parent: widget.parent,
              parentTitle: 'Task',
              entityNameSingular: 'Check List Item',
              entityNamePlural: 'Items',
              dao: DaoCheckListItem(),
              onDelete: (checklistitem) async => widget.daoJoin
                  .deleteFromParent(checklistitem!, widget.parent.parent!),
              onInsert: (checklistitem) async => widget.daoJoin
                  .insertForParent(checklistitem!, widget.parent.parent!),
              // ignore: discarded_futures
              fetchList: () async => _fetchItems(showCompleted),
              title: (checklistitem) =>
                  Text(checklistitem.description) as Widget,
              onEdit: (checklistitem) => CheckListItemEditScreen(
                    daoJoin: widget.daoJoin,
                    parent: widget.parent.parent!,
                    checkListItem: checklistitem,
                    billingType:
                        taskAndRate?.billingType ?? BillingType.timeAndMaterial,
                    hourlyRate: taskAndRate?.rate ?? MoneyEx.zero,
                  ),
              details: (entity, details) {
                final checklistitem = entity;
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ..._buildFieldsBasedOnItemType(checklistitem),
                      HMBText(checklistitem.dimensions),
                      if (checklistitem.completed)
                        const Text(
                          'Completed',
                          style: TextStyle(color: Colors.green),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async =>
                              _markAsCompleted(context, checklistitem),
                        ),
                    ]);
              },
              filterBar: (entity) => Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      HMBToggle(
                        label: 'Show Completed',
                        tooltip: showCompleted
                            ? 'Show Only Non-Completed Tasks'
                            : 'Show Completed Tasks',
                        initialValue: June.getState(ShowCompltedItems.new)
                            .showCompletedTasks,
                        onChanged: (value) {
                          setState(() {
                            June.getState(ShowCompltedItems.new).toggle();
                          });
                        },
                      ),
                    ],
                  )),
    );
  }

  Future<List<CheckListItem>> _fetchItems(bool showCompleted) async {
    final items = await widget.daoJoin.getByParent(widget.parent.parent);

    return items
        .where((item) => showCompleted ? item.completed : !item.completed)
        .toList();
  }

  List<Widget> _buildFieldsBasedOnItemType(CheckListItem checkListItem) {
    switch (checkListItem.itemTypeId) {
      case 5: // Labour
        return _buildLabourFields(checkListItem);
      case 1: // Materials - buy
      case 3: // Tools - buy
        return _buildBuyFields(checkListItem);
      case 2: // Materials - stock
      case 4: // Tools - stock
        return _buildStockFields(checkListItem);
      default:
        return [];
    }
  }

  List<Widget> _buildLabourFields(CheckListItem checkListItem) => [
        if (checkListItem.labourEntryMode == LabourEntryMode.hours)
          HMBText('Est: Hours: ${checkListItem.estimatedLabourHours} '
              'Cost: ${checkListItem.estimatedLabourCost} '),
        HMBText('Charge: ${checkListItem.charge} '
            'Margin (%): ${checkListItem.margin}'),
      ];

  List<Widget> _buildBuyFields(CheckListItem checkListItem) => [
        HMBText('Est: Unit Cost: ${checkListItem.estimatedMaterialUnitCost} '
            'Qty: ${checkListItem.estimatedMaterialQuantity} '),
        HMBText('Margin (%): ${checkListItem.margin} '
            'Charge: ${checkListItem.charge}'),
      ];

  List<Widget> _buildStockFields(CheckListItem checkListItem) => [
        HMBText(
          'Unit Charge: ${checkListItem.estimatedMaterialUnitCost} '
          'Qty: ${checkListItem.estimatedMaterialQuantity} ',
        ),
        HMBText('Margin (%): ${checkListItem.margin} '
            'Charge: ${checkListItem.charge}'),
      ];

  Future<void> _markAsCompleted(
      BuildContext context, CheckListItem item) async {
    final costController = TextEditingController()
      ..text = item.estimatedMaterialUnitCost.toString();

    final quantityController = TextEditingController()
      ..text = (item.estimatedMaterialQuantity == Fixed.zero
              ? Fixed.one
              : item.estimatedMaterialQuantity)
          .toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HMBTextField(
              controller: costController,
              labelText: 'Cost per item (optional)',
              keyboardType: TextInputType.number,
            ),
            HMBTextField(
              controller: quantityController,
              labelText: 'Quantity (optional)',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      final quantity = Fixed.tryParse(quantityController.text) ?? Fixed.one;
      final unitCost = MoneyEx.tryParse(costController.text);

      await DaoCheckListItem().markAsCompleted(item, unitCost, quantity);
    }
  }
}

class ShowCompltedItems extends JuneState {
  bool showCompletedTasks = false;

  void toggle() {
    showCompletedTasks = !showCompletedTasks;
    refresh(); // Notify listeners to rebuild
  }
}
