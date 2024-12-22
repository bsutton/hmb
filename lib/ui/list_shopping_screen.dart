// ignore_for_file: discarded_futures

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_supplier.dart';
import '../../entity/job.dart';
import '../../entity/supplier.dart';
import '../dao/dao_customer.dart';
import '../dao/dao_job.dart';
import '../dao/dao_task.dart';
import '../dao/dao_task_item.dart';
import '../dao/dao_task_item_type.dart';
import '../entity/customer.dart';
import '../util/app_title.dart';
import '../util/format.dart';
import '../util/money_ex.dart';
import 'crud/tool/stock_take_wizard.dart';
import 'list_packing_screen.dart';
import 'widgets/add_task_item.dart';
import 'widgets/async_state.dart';
import 'widgets/fields/hmb_text_field.dart';
import 'widgets/hmb_button.dart';
import 'widgets/hmb_search.dart';
import 'widgets/layout/hmb_spacer.dart';
import 'widgets/select/hmb_droplist.dart';
import 'widgets/select/hmb_droplist_multi.dart';
import 'widgets/surface.dart';
import 'widgets/text/hmb_text_themes.dart';

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
  String? filter;

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
      if (Strings.isBlank(filter)) {
        _taskItems.add(TaskItemContext(task!, taskItem, billingType));
      } else {
        if (taskItem.description.toLowerCase().contains(filter!)) {
          _taskItems.add(TaskItemContext(task!, taskItem, billingType));
        }
      }
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
          HMBButton(
            onPressed: () => Navigator.of(context).pop(false),
            label: 'Cancel',
          ),
          HMBButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: 'Complete',
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
                HMBButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  label: 'No',
                ),
                HMBButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  label: 'Yes',
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
        body: Surface(
          elevation: SurfaceElevation.e6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HMBSearchWithAdd(onSearch: (filter) {
                      this.filter = filter;
                      _loadTaskItems();
                    }, onAdd: () async {
                      await showAddItemDialog(context, AddType.shopping);
                      await _loadTaskItems();
                    }),
                    HMBDroplistMultiSelect<Job>(
                      initialItems: () async => _selectedJobs,
                      items: (filter) async => DaoJob().getActiveJobs(filter),
                      format: (job) => job.summary,
                      onChanged: (selectedJobs) async {
                        _selectedJobs = selectedJobs;
                        await _loadTaskItems();
                      },
                      title: 'Filter by Jobs',
                      backgroundColor: SurfaceElevation.e6.color,
                      required: false,
                    ),
                    const SizedBox(height: 10),
                    HMBDroplist<Supplier>(
                      selectedItem: () async => _selectedSupplier,
                      items: (filter) async =>
                          DaoSupplier().getByFilter(filter),
                      format: (supplier) => supplier.name,
                      onChanged: (supplier) async {
                        _selectedSupplier = supplier;
                        await _loadTaskItems();
                      },
                      title: 'Supplier',
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
                                return _buildShoppingItem(context, item);
                              },
                            );
                          } else {
                            // Desktop layout
                            return GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                // childAspectRatio: 3,
                                mainAxisExtent: 256,
                              ),
                              itemCount: _taskItems.length,
                              itemBuilder: (context, index) {
                                final item = _taskItems[index];
                                return _buildShoppingItem(context, item);
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
        ),
      );

  Center _showEmpty() => const Center(child: Text('''
No Shopping Items found 
- Shopping items are taken from Task Items 
that are marked as "Materials - buy" or "Tools - buy".
If you were expecting to see items here - check the Job's Status is active.
'''));

  /// build a card for each shipping item.
  Widget _buildShoppingItem(
          BuildContext context, TaskItemContext itemContext) =>
      Column(
        children: [
          const HMBSpacer(height: true),
          SurfaceCard(
            title: itemContext.taskItem.description,
            height: 240,
            body: FutureBuilderEx(
              // Fetch the job associated with the task
              future: CustomerAndJob.fetch(itemContext),
              builder: (context, details) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HMBTextLine('Customer: ${details!.customer.name}'),
                      HMBTextLine('Job: ${details.job.summary}'),
                      HMBTextLine('Task: ${itemContext.task.name}'),
                      if (details.supplier != null)
                        HMBTextLine('Supplier: ${details.supplier!.name}'),
                      HMBTextLine(
                          '''Scheduled Date: ${formatDate(details.job.startDate)}'''),
                      HMBTextLine(itemContext.taskItem.dimensions),
                      if (itemContext.taskItem.completed)
                        const HMBTextLine(
                          'Completed',
                          colour: Colors.green,
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () async => _markAsCompleted(itemContext),
                  ),
                ],
              ),
            ),
            onPressed: () async => _markAsCompleted(itemContext),
          ),
        ],
      );
}

class CustomerAndJob {
  CustomerAndJob._internal(this.customer, this.job, this.supplier);
  static Future<CustomerAndJob> fetch(TaskItemContext itemContext) async {
    final job = await DaoJob().getJobForTask(itemContext.task.id);
    final customer = await DaoCustomer().getByJob(job!.id);
    final supplier =
        await DaoSupplier().getById(itemContext.taskItem.supplierId);

    return CustomerAndJob._internal(customer!, job, supplier);
  }

  final Customer customer;
  final Job job;
  final Supplier? supplier;
}
