// ignore_for_file: discarded_futures

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_supplier.dart';
import '../../../entity/job.dart';
import '../../../entity/supplier.dart';
import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_job_activity.dart';
import '../../dao/dao_task.dart';
import '../../dao/dao_task_item.dart';
import '../../entity/customer.dart';
import '../../entity/job_activity.dart';
import '../../entity/task_item.dart';
import '../../util/app_title.dart';
import '../../util/format.dart';
import '../widgets/select/select.g.dart';
import '../widgets/widgets.g.dart';
import 'list_packing_screen.dart';
import 'purchased_item_card.dart';
import 'return_item_card.dart';
import 'to_purchase_item_card.dart';

enum ScheduleFilter {
  all,
  today,
  nextThreeDays,
  week;

  String get displayName {
    switch (this) {
      case ScheduleFilter.all:
        return 'All';
      case ScheduleFilter.today:
        return 'Today';
      case ScheduleFilter.nextThreeDays:
        return 'Next 3 Days';
      case ScheduleFilter.week:
        return 'This Week';
    }
  }

  /// Returns true if [scheduledDate] falls within the period defined by this filter.
  bool includes(DateTime scheduledDate, {DateTime? now}) {
    now ??= DateTime.now();
    // Set the base of today to midnight
    final todayDate = DateTime(now.year, now.month, now.day);
    switch (this) {
      case ScheduleFilter.all:
        return true;
      case ScheduleFilter.today:
        return scheduledDate.year == todayDate.year &&
            scheduledDate.month == todayDate.month &&
            scheduledDate.day == todayDate.day;
      case ScheduleFilter.nextThreeDays:
        // Include today plus the next 2 days (3 days total).
        final end = todayDate.add(const Duration(days: 3));
        return !scheduledDate.isBefore(todayDate) &&
            scheduledDate.isBefore(end);
      case ScheduleFilter.week:
        // Include today plus the next 6 days (7 days total).
        final end = todayDate.add(const Duration(days: 7));
        return !scheduledDate.isBefore(todayDate) &&
            scheduledDate.isBefore(end);
    }
  }
}

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  _ShoppingScreenState createState() => _ShoppingScreenState();
}

enum ShoppingMode { toPurchase, purchased, returns }

extension ShoppingModeX on ShoppingMode {
  String get displayName {
    switch (this) {
      case ShoppingMode.toPurchase:
        return 'To Purchase';
      case ShoppingMode.purchased:
        return 'Purchased';
      case ShoppingMode.returns:
        return 'Returns';
    }
  }
}

class _ShoppingScreenState extends DeferredState<ShoppingScreen> {
  static ShoppingMode _selectedMode = ShoppingMode.toPurchase;
  final _taskItems = <TaskItemContext>[];
  List<Job> _selectedJobs = [];
  Supplier? _selectedSupplier;
  String? filter;
  static ScheduleFilter _selectedScheduleFilter = ScheduleFilter.all;

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Shopping');
    await _loadTaskItems();
  }

  Future<void> _loadTaskItems() async {
    List<TaskItem> taskItems;
    switch (_selectedMode) {
      case ShoppingMode.toPurchase:
        taskItems = await DaoTaskItem().getShoppingItems(
          jobs: _selectedJobs,
          supplier: _selectedSupplier,
        );
      case ShoppingMode.purchased:
        taskItems = await DaoTaskItem().getPurchasedItems(
          since: DateTime.now().subtract(const Duration(days: 1)),
          jobs: _selectedJobs,
          supplier: _selectedSupplier,
        );
      case ShoppingMode.returns:
        taskItems = await DaoTaskItem().getReturnedItems(
          jobs: _selectedJobs,
          supplier: _selectedSupplier,
        );
    }

    // apply text & schedule filters (same as before)…
    _taskItems.clear();
    for (final taskItem in taskItems) {
      final task = await DaoTask().getById(taskItem.taskId);
      final billingType = await DaoTask().getBillingTypeByTaskItem(taskItem);
      final wasReturned = await DaoTaskItem().wasReturned(taskItem.id);

      // Apply text filter if present
      if (!Strings.isBlank(filter) &&
          !taskItem.description.toLowerCase().contains(filter!.toLowerCase())) {
        continue;
      }
      // Apply schedule filter (if not "All")
      if (_selectedScheduleFilter != ScheduleFilter.all) {
        final job = await DaoJob().getJobForTask(task!.id);
        final nextActivity =
            job == null
                ? null
                : await DaoJobActivity().getNextActivityByJob(job.id);
        if (nextActivity == null ||
            !_selectedScheduleFilter.includes(nextActivity.start)) {
          continue;
        }
      }

      _taskItems.add(
        TaskItemContext(
          task: task!,
          taskItem: taskItem,
          billingType: billingType,
          wasReturned: wasReturned,
        ),
      );
    }
    setState(() {});
  }

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
                HMBDroplist<ShoppingMode>(
                  selectedItem: () async => _selectedMode,
                  items: (f) async => ShoppingMode.values,
                  format: (m) => m.displayName,
                  onChanged: (m) async {
                    _selectedMode = m ?? ShoppingMode.toPurchase;
                    await _loadTaskItems();
                  },
                  title: 'View',
                  required: false,
                ).help(
                  'Toggle View',
                  'Toggle between items to purchase, recently purchased, or returns',
                ),
                HMBSearchWithAdd(
                  onSearch: (filter) {
                    this.filter = filter;
                    _loadTaskItems();
                  },
                  onAdd: () async {
                    await showAddItemDialog(context, AddType.shopping);
                    await _loadTaskItems();
                  },
                ),
                HMBDroplistMultiSelect<Job>(
                  initialItems: () async => _selectedJobs,
                  items: (filter) => DaoJob().getActiveJobs(filter),
                  format: (job) => job.summary,
                  onChanged: (selectedJobs) async {
                    _selectedJobs = selectedJobs;
                    await _loadTaskItems();
                  },
                  title: 'Jobs',
                  backgroundColor: SurfaceElevation.e6.color,
                  required: false,
                ).help(
                  'Filter by Job',
                  '''
Allows you to filter the shopping list to items from specific Jobs.

If your Job isn't showing then you need to update its status to an Active one such as 'Scheduled, In Progress...' ''',
                ),
                const SizedBox(height: 10),
                HMBDroplist<Supplier>(
                  selectedItem: () async => _selectedSupplier,
                  items: (filter) => DaoSupplier().getByFilter(filter),
                  format: (supplier) => supplier.name,
                  onChanged: (supplier) async {
                    _selectedSupplier = supplier;
                    await _loadTaskItems();
                  },
                  title: 'Supplier',
                  required: false,
                ).help(
                  'Filter by Supplier',
                  'When adding Task Items, if you enter the supplier you can filter by supplier',
                ),
                const SizedBox(height: 10),
                HMBDroplist<ScheduleFilter>(
                  selectedItem: () async => _selectedScheduleFilter,
                  items: (filter) async => ScheduleFilter.values,
                  format: (schedule) => schedule.displayName,
                  onChanged: (schedule) async {
                    _selectedScheduleFilter = schedule ?? ScheduleFilter.all;
                    await _loadTaskItems();
                  },
                  title: 'Schedule',
                  required: false,
                ).help(
                  'Filter by Schedule',
                  'Filter shopping items by job scheduled date (Today, Next 3 Days, or This Week)',
                ),
              ],
            ),
          ),
          Expanded(
            child: DeferredBuilder(
              this,
              builder: (context) {
                if (_taskItems.isEmpty) {
                  return _showEmpty();
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 900;
                    return isMobile
                        ? ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _taskItems.length,
                          itemBuilder:
                              (context, index) => _buildShoppingItem(
                                context,
                                _taskItems[index],
                              ),
                        )
                        : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.5,
                                mainAxisExtent: 256,
                              ),
                          itemCount: _taskItems.length,
                          itemBuilder:
                              (context, index) => _buildShoppingItem(
                                context,
                                _taskItems[index],
                              ),
                        );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
  Center _showEmpty() => const Center(
    child: Text('''
No Shopping Items found 
- Shopping items are taken from Task Items 
that are marked as "Materials - buy" or "Tools - buy".
If you were expecting to see items here - check the Job's Status is active.
'''),
  );

  Widget _buildShoppingItem(BuildContext context, TaskItemContext itemContext) {
    switch (_selectedMode) {
      case ShoppingMode.toPurchase:
        return ToPurchaseItemCard(
          itemContext: itemContext,
          onReload: _loadTaskItems,
        );
      case ShoppingMode.purchased:
        return PurchasedItemCard(
          itemContext: itemContext,
          onReload: _loadTaskItems,
        );
      case ShoppingMode.returns:
        return ReturnItemCard(
          itemContext: itemContext,
          onReload: _loadTaskItems,
        );
    }
  }

  // Widget _buildShoppingItem2(
  //   BuildContext context,
  //   TaskItemContext itemContext,
  // ) {
  //   final taskItem = itemContext.taskItem;

  //   return SurfaceCard(
  //     title: taskItem.description,
  //     height: 240,
  //     body: FutureBuilderEx(
  //       future: CustomerAndJob.fetch(itemContext),
  //       builder: (ctx, details) {
  //         final det = details!;
  //         // final isReturnMode = _selectedMode == ShoppingMode.returns;
  //         // // Only material‐buy and tools - buy, not already returned, may be returned:
  //         // final canReturn =
  //         //     isReturnMode &&
  //         //     (TaskItemTypeEnum.fromId(taskItem.itemTypeId) ==
  //         //             TaskItemTypeEnum.materialsBuy ||
  //         //         TaskItemTypeEnum.fromId(taskItem.itemTypeId) ==
  //         //             TaskItemTypeEnum.toolsBuy) &&
  //         //     !itemContext.wasReturned;

  //         return Row(
  //           children: [
  //             ItemCardCommon(det: det, taskItem: taskItem),

  //             // Action Button:
  //           ],
  //         );
  //       },
  //     ),
  //   );
  // }

  Future<List<TaskItemContext>> withContext(List<TaskItem> items) async {
    final itemsWithContext = <TaskItemContext>[];

    for (final item in items) {
      final task = await DaoTask().getById(item.taskId);
      final billing = await DaoTask().getBillingTypeByTaskItem(item);
      final wasReturned = await DaoTaskItem().wasReturned(item.id);
      itemsWithContext.add(
        TaskItemContext(
          task: task!,
          taskItem: item,
          billingType: billing,
          wasReturned: wasReturned,
        ),
      );
    }
    return itemsWithContext;
  }
}

class CustomerAndJob {
  CustomerAndJob._internal(
    this.customer,
    this.job,
    this.supplier,
    this.nextActivity,
  );
  static Future<CustomerAndJob> fetch(TaskItemContext itemContext) async {
    final job = await DaoJob().getJobForTask(itemContext.task.id);
    final customer = await DaoCustomer().getByJob(job!.id);
    final supplier =
        itemContext.taskItem.supplierId == null
            ? null
            : await DaoSupplier().getById(itemContext.taskItem.supplierId);
    final nextActivity = await DaoJobActivity().getNextActivityByJob(job.id);

    return CustomerAndJob._internal(customer!, job, supplier, nextActivity);
  }

  final Customer customer;
  final Job job;
  final Supplier? supplier;
  final JobActivity? nextActivity;

  String dateOfNextActivity() {
    if (nextActivity == null) {
      return 'Not Scheduled';
    }
    return formatDate(nextActivity!.start);
  }
}
