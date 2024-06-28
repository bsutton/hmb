import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_checklist_item.dart';
import '../../entity/check_list_item.dart';
import '../../widgets/hmb_text_field.dart';
import '../dao/dao_job.dart';
import '../dao/dao_task.dart';
import '../util/format.dart';
import '../util/money_ex.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ShoppingScreenState createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  late Future<List<CheckListItem>> _checkListItemsFuture;
  late List<CheckListItem> _checkListItems;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCheckListItems());
  }

  Future<void> _loadCheckListItems() async {
    _checkListItemsFuture = DaoCheckListItem().getIncompleteItems();
    _checkListItems = await _checkListItemsFuture;
    setState(() {});
  }

  Future<void> _markAsCompleted(CheckListItem item) async {
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
      final quantity = int.tryParse(quantityController.text) ?? 1;
      final cost = MoneyEx.tryParse(costController.text) * quantity;

      await DaoCheckListItem().markAsCompleted(item, cost);
      await _loadCheckListItems();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Shopping List'),
        ),
        body: FutureBuilder<List<CheckListItem>>(
          future: _checkListItemsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('''
No Shopping Items found 
- shopping items are taken from Task Check list items 
that are marked as "buy".'''));
            }

            _checkListItems = snapshot.data!;
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
          },
        ),
      );

  Widget _buildListItem(BuildContext context, CheckListItem item) => Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 2,
        child: ListTile(
          title: Text(item.description),
          subtitle: FutureBuilderEx(
              // ignore: discarded_futures
              future: DaoTask().getTaskForCheckListItem(item),
              builder: (context, task) => FutureBuilderEx(
                  // ignore: discarded_futures
                  future: DaoJob().getJobForTask(task!),
                  builder: (context, job) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Job: ${job!.summary}'),
                          Text('Task: ${task.name}'),
                          Text('Scheduled Date: ${formatDate(job.startDate)}'),
                          if (item.completed)
                            const Text(
                              'Completed',
                              style: TextStyle(color: Colors.green),
                            ),
                        ],
                      ))),
          trailing: IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () async => _markAsCompleted(item),
          ),
          onTap: () async => _markAsCompleted(item),
        ),
      );
}
