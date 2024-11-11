// ignore_for_file: discarded_futures

import 'dart:async';

import 'package:fixed/fixed.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_checklist_item.dart';
import '../../dao/dao_supplier.dart';
import '../../entity/check_list_item.dart';
import '../../entity/job.dart';
import '../../entity/supplier.dart';
import '../dao/dao_check_list_item_type.dart';
import '../dao/dao_customer.dart';
import '../dao/dao_job.dart';
import '../dao/dao_task.dart';
import '../dao/dao_tool.dart';
import '../entity/tool.dart';
import '../util/format.dart';
import '../util/money_ex.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/select/hmb_droplist_multi.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ShoppingScreenState createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  late Future<List<CheckListItem>> _checkListItemsFuture;
  List<Job> _selectedJobs = [];
  Supplier? _selectedSupplier;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCheckListItems());
  }

  Future<void> _loadCheckListItems() async {
    _checkListItemsFuture = DaoCheckListItem().getShoppingItems(
      jobs: _selectedJobs,
      supplier: _selectedSupplier,
    );
    setState(() {});
  }

  Future<void> _markAsCompleted(CheckListItem item) async {
    final costController = TextEditingController();
    final quantityController = TextEditingController();

    costController.text = item.estimatedMaterialUnitCost.toString();
    quantityController.text = item.estimatedMaterialQuantity.toString();

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
      await _loadCheckListItems();

      // Check if item type is "Tool - buy" and prompt to add to tool list
      if (item.itemTypeId == (await DaoCheckListItemType().getToolsBuy()).id) {
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

          if (addTool ?? false) {
            final tool = Tool.forInsert(
              name: item.description,
              cost: unitCost,
              supplierId: item.supplierId,
              datePurchased: DateTime.now(),
              // Add any other relevant details
            );
            await DaoTool().insertTool(tool);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Shopping List'),
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
                        await _loadCheckListItems();
                      },
                      title: 'Filter by Jobs',
                      required: false),
                  const SizedBox(height: 10),
                  HMBDroplist<Supplier>(
                      selectedItem: () async => _selectedSupplier,
                      items: (filter) async =>
                          DaoSupplier().getByFilter(filter),
                      format: (supplier) => supplier.name,
                      onChanged: (supplier) async {
                        _selectedSupplier = supplier;
                        await _loadCheckListItems();
                      },
                      title: 'Filter by Supplier',
                      required: false),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilderEx<List<CheckListItem>>(
                future: _checkListItemsFuture,
                builder: (context, _checkListItems) {
                  if (_checkListItems == null || _checkListItems.isEmpty) {
                    return _showEmpty();
                  } else {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 600) {
                          // Mobile layout
                          return ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _checkListItems.length,
                            itemBuilder: (context, index) {
                              final item = _checkListItems[index];
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
                            itemCount: _checkListItems.length,
                            itemBuilder: (context, index) {
                              final item = _checkListItems[index];
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
      );

  Center _showEmpty() => const Center(child: Text('''
No Shopping Items found 
- Shopping items are taken from Task Check list items 
that are marked as "Materials - buy" or "Tools - buy".'''));
  Widget _buildListItem(BuildContext context, CheckListItem item) => Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 2,
        child: ListTile(
          title: Text(item.description),
          subtitle: FutureBuilderEx(
            // Fetch the task associated with the checklist item
            future: DaoTask().getTaskForCheckListItem(item),
            builder: (context, task) => FutureBuilderEx(
              // Fetch the job associated with the task
              future: DaoJob().getJobForTask(task!.id),
              builder: (context, job) => FutureBuilderEx(
                // Fetch the customer associated with the job
                future: DaoCustomer().getByJob(job!.id),
                builder: (context, customer) => FutureBuilderEx(
                  // Fetch the supplier associated with the checklist item
                  future: DaoSupplier().getById(item.supplierId),
                  builder: (context, supplier) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer: ${customer!.name}'),
                      Text('Job: ${job.summary}'),
                      Text('Task: ${task.name}'),
                      if (supplier != null) Text('Supplier: ${supplier.name}'),
                      Text('''Scheduled Date: ${formatDate(job.startDate)}'''),
                      Text(item.dimensions),
                      if (item.completed)
                        const Text(
                          'Completed',
                          style: TextStyle(color: Colors.green),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () async => _markAsCompleted(item),
          ),
          onTap: () async => _markAsCompleted(item),
        ),
      );
}
