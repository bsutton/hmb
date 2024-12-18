// ignore_for_file: discarded_futures

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../dao/dao_supplier.dart';
import '../../entity/job.dart';
import '../../entity/supplier.dart';
import '../dao/dao_customer.dart';
import '../dao/dao_job.dart';
import '../dao/dao_task.dart';
import '../dao/dao_task_item.dart';
import '../dao/dao_task_item_type.dart';
import '../entity/task.dart';
import '../entity/task_item.dart';
import '../entity/task_item_type.dart';
import '../util/app_title.dart';
import '../util/format.dart';
import '../util/measurement_type.dart';
import '../util/money_ex.dart';
import '../util/units.dart';
import 'crud/tool/stock_take_wizard.dart';
import 'list_packing_screen.dart';
import 'widgets/async_state.dart';
import 'widgets/fields/hmb_text_field.dart';
import 'widgets/select/hmb_droplist.dart';
import 'widgets/select/hmb_droplist_multi.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ShoppingScreenState createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends AsyncState<ShoppingScreen, void> {
  late final _taskItems = <TaskItemContext>[];
  List<Job> _selectedJobs = [];
  Supplier? _selectedSupplier;

  @override
  Future<void> asyncInitState() async {
    await _loadTaskItems();
    setAppTitle('Shopping');
  }

  Future<void> _loadTaskItems() async {
    final taskItems = await DaoTaskItem().getShoppingItems(
      jobs: _selectedJobs,
      supplier: _selectedSupplier,
    );

    _taskItems.clear();
    for (final taskItem in taskItems) {
      final task = await DaoTask().getById(taskItem.taskId);
      final billingType = await DaoTask().getBillingTypeByTaskItem(taskItem);
      _taskItems.add(TaskItemContext(task!, taskItem, billingType));
    }
    setState(() {});
  }

  Future<void> _markAsCompleted(TaskItemContext itemContext) async {
    final costController = TextEditingController();
    final quantityController = TextEditingController();

    costController.text =
        itemContext.taskItem.estimatedMaterialUnitCost.toString();
    quantityController.text =
        itemContext.taskItem.estimatedMaterialQuantity.toString();

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

      // Check if item type is "Tool - buy" and prompt to add to tool list
      if (itemContext.taskItem.itemTypeId ==
          (await DaoTaskItemType().getToolsBuy()).id) {
        if (mounted) {
          final addTool = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Add Tool to Tool List?'),
              content: const Text(
                  'Would you like to add this tool to your tool list?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          );

          if ((addTool ?? false) && mounted) {
            await ToolStockTakeWizard.start(
                context: context,
                onFinish: (reason) async {
                  Navigator.of(context).pop();
                },
                cost: unitCost,
                name: itemContext.taskItem.description,
                offerAnother: false);
          }
        }
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) => Scaffold(
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
                  const SizedBox(height: 10),
                  HMBDroplist<Supplier>(
                    selectedItem: () async => _selectedSupplier,
                    items: (filter) async => DaoSupplier().getByFilter(filter),
                    format: (supplier) => supplier.name,
                    onChanged: (supplier) async {
                      _selectedSupplier = supplier;
                      await _loadTaskItems();
                    },
                    title: 'Filter by Supplier',
                    required: false,
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilderEx<void>(
                future: initialised,
                builder: (context, _) {
                  if (_taskItems.isEmpty) {
                    return _showEmpty();
                  } else {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 600) {
                          // Mobile layout
                          return ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _taskItems.length,
                            itemBuilder: (context, index) {
                              final item = _taskItems[index];
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
                            itemCount: _taskItems.length,
                            itemBuilder: (context, index) {
                              final item = _taskItems[index];
                              return _buildListItem(context, item);
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
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddItemDialog(context),
          child: const Icon(Icons.add),
        ),
      );

  Future<void> _showAddItemDialog(BuildContext context) async {
    Job? selectedJob;
    Task? selectedTask;
    TaskItemTypeEnum? selectedItemType;
    final descriptionController = TextEditingController();
    final quantityController = TextEditingController();
    final unitCostController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Shopping Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Job Selection Dropdown
                HMBDroplist<Job>(
                  title: 'Select Job',
                  selectedItem: () async => selectedJob,
                  items: (filter) async => DaoJob().getActiveJobs(filter),
                  format: (job) => job.summary,
                  onChanged: (job) {
                    setState(() {
                      selectedJob = job;
                      selectedTask = null; // Reset task selection
                    });
                  },
                ),
                const SizedBox(height: 10),
                // Task Selection Dropdown (dependent on selected job)
                if (selectedJob != null)
                  HMBDroplist<Task>(
                    title: 'Select Task',
                    selectedItem: () async => selectedTask,
                    items: (filter) async =>
                        DaoTask().getTasksByJob(selectedJob!.id),
                    format: (task) => task.name,
                    onChanged: (task) {
                      setState(() {
                        selectedTask = task;
                      });
                    },
                  ),
                const SizedBox(height: 10),
                // Item Type Selection Dropdown
                HMBDroplist<TaskItemTypeEnum>(
                  title: 'Item Type',
                  selectedItem: () async => selectedItemType,
                  items: (filter) async => [
                    TaskItemTypeEnum.toolsBuy,
                    TaskItemTypeEnum.materialsBuy,
                  ],
                  format: (type) => type.description,
                  onChanged: (type) {
                    setState(() {
                      selectedItemType = type;
                    });
                  },
                ),
                const SizedBox(height: 10),
                // Description Input
                HMBTextField(
                  controller: descriptionController,
                  labelText: 'Description',
                ),
                // Quantity Input
                HMBTextField(
                  controller: quantityController,
                  labelText: 'Quantity',
                  keyboardType: TextInputType.number,
                ),
                // Unit Cost Input
                HMBTextField(
                  controller: unitCostController,
                  labelText: 'Unit Cost',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedJob != null &&
                    selectedTask != null &&
                    selectedItemType != null) {
                  final quantity =
                      Fixed.tryParse(quantityController.text) ?? Fixed.one;
                  final unitCost = MoneyEx.tryParse(unitCostController.text);

                  // Create and insert the new TaskItem
                  final newItem = TaskItem.forInsert(
                      taskId: selectedTask!.id,
                      description: descriptionController.text,
                      itemTypeId:
                          (await DaoTaskItemType().getMaterialsBuy()).id,
                      estimatedMaterialQuantity: quantity,
                      estimatedMaterialUnitCost: unitCost,
                      estimatedLabourCost: null,
                      estimatedLabourHours: null,
                      charge: null,
                      chargeSet: false,
                      dimension1: Fixed.zero,
                      dimension2: Fixed.zero,
                      dimension3: Fixed.zero,
                      labourEntryMode: LabourEntryMode.hours,
                      margin: Percentage.zero,
                      measurementType: MeasurementType.length,
                      units: Units.defaultUnits,
                      url: '');

                  await DaoTaskItem().insert(newItem);
                  await _loadTaskItems();

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Center _showEmpty() => const Center(child: Text('''
No Shopping Items found 
- Shopping items are taken from Task Items 
that are marked as "Materials - buy" or "Tools - buy".
If you were expecting to see items here - check the Job's Status is active.
'''));
  Widget _buildListItem(BuildContext context, TaskItemContext itemContext) =>
      Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 2,
        child: ListTile(
          title: Text(itemContext.taskItem.description),
          subtitle: FutureBuilderEx(
            // Fetch the job associated with the task
            future: DaoJob().getJobForTask(itemContext.task.id),
            builder: (context, job) => FutureBuilderEx(
              // Fetch the customer associated with the job
              future: DaoCustomer().getByJob(job!.id),
              builder: (context, customer) => FutureBuilderEx(
                // Fetch the supplier associated with the checklist item
                future: DaoSupplier().getById(itemContext.taskItem.supplierId),
                builder: (context, supplier) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer: ${customer!.name}'),
                    Text('Job: ${job.summary}'),
                    Text('Task: ${itemContext.task.name}'),
                    if (supplier != null) Text('Supplier: ${supplier.name}'),
                    Text('''Scheduled Date: ${formatDate(job.startDate)}'''),
                    Text(itemContext.taskItem.dimensions),
                    if (itemContext.taskItem.completed)
                      const Text(
                        'Completed',
                        style: TextStyle(color: Colors.green),
                      ),
                  ],
                ),
              ),
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () async => _markAsCompleted(itemContext),
          ),
          onTap: () async => _markAsCompleted(itemContext),
        ),
      );
}
