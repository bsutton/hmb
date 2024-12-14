import 'dart:async';

import 'package:fixed/fixed.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../dao/dao_customer.dart';
import '../dao/dao_job.dart';
import '../dao/dao_task.dart';
import '../dao/dao_task_item.dart';
import '../entity/job.dart';
import '../entity/task.dart';
import '../entity/task_item.dart';
import '../entity/task_item_type.dart';
import '../util/format.dart';
import '../util/money_ex.dart';
import 'widgets/async_state.dart';
import 'widgets/fields/hmb_text_field.dart';
import 'widgets/hmb_toast.dart';
import 'widgets/select/hmb_droplist_multi.dart';
import 'widgets/text/hmb_text_themes.dart';

class PackingScreen extends StatefulWidget {
  const PackingScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PackingScreenState createState() => _PackingScreenState();
}

class TaskItemContext {
  TaskItemContext(this.task, this.taskItem, this.billingType);
  TaskItem taskItem;
  Task task;
  BillingType billingType;
}

class _PackingScreenState extends AsyncState<PackingScreen, void> {
  final taskItemsContexts = <TaskItemContext>[];
  List<Job> _selectedJobs = [];

  @override
  Future<void> asyncInitState() async {
    await _loadTaskItems();
  }

  Future<void> _loadTaskItems() async {
    // Pass the selected jobs to filter the packing items
    final taskItems = await DaoTaskItem().getPackingItems(jobs: _selectedJobs);

    taskItemsContexts.clear();

    for (final taskItem in taskItems) {
      final task = await DaoTask().getById(taskItem.taskId);

      final billingType = await DaoTask().getBillingTypeByTaskItem(taskItem);
      taskItemsContexts.add(TaskItemContext(task!, taskItem, billingType));
    }

    setState(() {});
  }

  Future<void> _markAsCompleted(TaskItemContext itemContext) async {
    final costController = TextEditingController();
    final quantityController = TextEditingController();

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

      await DaoTaskItem().markAsCompleted(
          itemContext.billingType, itemContext.taskItem, unitCost, quantity);
      await _loadTaskItems();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const HMBPageTitle('Packing List'),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HMBDroplistMultiSelect<Job>(
                    initialItems: () async => _selectedJobs,
                    items: (filter) async => DaoJob().getActiveJobs(filter),
                    format: (job) => job.summary,
                    onChanged: (selectedJobs) async {
                      _selectedJobs = selectedJobs;
                      await _loadTaskItems();
                    },
                    title: 'Filter by Jobs',
                    required: false,
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilderEx<void>(
                future: initialised,
                builder: (context, _taskItems) {
                  if (taskItemsContexts.isEmpty) {
                    return _showEmpty();
                  } else {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 600) {
                          // Mobile layout
                          return ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: taskItemsContexts.length,
                            itemBuilder: (context, index) {
                              final item = taskItemsContexts[index];
                              return _buildListItem(context, item);
                            },
                          );
                        } else {
                          // Desktop layout
                          return GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 3,
                            ),
                            itemCount: taskItemsContexts.length,
                            itemBuilder: (context, index) {
                              final itemContext = taskItemsContexts[index];
                              return _buildListItem(context, itemContext);
                            },
                          );
                        }
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      );

  Center _showEmpty() => const Center(child: Text('''
No Packing Items found 
- Packing items are taken from Task items 
that are marked as "Materials - stock" or "Tools - own".
If you were expecting to see items here - check the Job's Status is active.
'''));

  Widget _buildListItem(
    BuildContext context,
    TaskItemContext itemContext,
  ) =>
      Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 2,
        child: ListTile(
          title: Text(itemContext.taskItem.description),
          subtitle: FutureBuilderEx(
            // ignore: discarded_futures
            future: DaoJob().getJobForTask(itemContext.task.id),
            builder: (context, job) => FutureBuilderEx(
              // ignore: discarded_futures
              future: DaoCustomer().getByJob(job!.id),
              builder: (context, customer) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: ${customer!.name}'),
                  Text('Job: ${job.summary}'),
                  Text('Task: ${itemContext.task.name}'),
                  Text('''Scheduled Date: ${formatDate(job.startDate)}'''),
                  Text('Dimensions: ${itemContext.taskItem.dimension1} '
                      'x ${itemContext.taskItem.dimension2} '
                      'x ${itemContext.taskItem.dimension3} '
                      '${itemContext.taskItem.measurementType}'),
                  if (itemContext.taskItem.completed)
                    const Text(
                      'Completed',
                      style: TextStyle(color: Colors.green),
                    ),
                ],
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.blue),
                onPressed: () async => _moveToShoppingList(itemContext),
              ),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () async => _markAsCompleted(itemContext),
              ),
            ],
          ),
          onTap: () async => _markAsCompleted(itemContext),
        ),
      );

  Future<void> _moveToShoppingList(TaskItemContext itemContext) async {
    final itemType = TaskItemTypeEnum.fromId(itemContext.taskItem.itemTypeId);

    // Determine the new item type
    final newType = switch (itemType) {
      TaskItemTypeEnum.toolsOwn => TaskItemTypeEnum.toolsBuy,
      TaskItemTypeEnum.materialsStock => TaskItemTypeEnum.materialsBuy,
      _ => null, // Other types are not moved
    };

    if (newType == null) {
      HMBToast.error('Item cannot be moved to shopping list.');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Shopping List'),
        content: Text(
          'Are you sure you want to move "${itemContext.taskItem.description}" '
          'to the shopping list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    // If the user cancels, do nothing
    if (confirmed != true) {
      return;
    }

    // Update the item type in the database
    final taskItem = itemContext.taskItem..itemTypeId = newType.id;
    await DaoTaskItem().update(taskItem);

    // Reload the list to reflect the changes
    await _loadTaskItems();

    // Show confirmation
    HMBToast.info('Item moved to shopping list.');
  }
}
