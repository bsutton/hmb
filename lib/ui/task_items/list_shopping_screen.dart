/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/app_title.dart';
import '../../util/format.dart';
import '../widgets/layout/hmb_spacer.dart';
import '../widgets/select/hmb_filter_line.dart';
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

  bool includes(DateTime scheduledDate, {DateTime? now}) {
    now ??= DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case ScheduleFilter.all:
        return true;
      case ScheduleFilter.today:
        return scheduledDate.year == today.year &&
            scheduledDate.month == today.month &&
            scheduledDate.day == today.day;
      case ScheduleFilter.nextThreeDays:
        final end = today.add(const Duration(days: 3));
        return !scheduledDate.isBefore(today) && scheduledDate.isBefore(end);
      case ScheduleFilter.week:
        final end = today.add(const Duration(days: 7));
        return !scheduledDate.isBefore(today) && scheduledDate.isBefore(end);
    }
  }
}

enum ShoppingMode {
  toPurchase('To Purchase'),
  purchased('Purchased'),
  returns('Returns');

  const ShoppingMode(this.displayName);
  final String displayName;
}

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ShoppingScreenState createState() => ShoppingScreenState();
}

class ShoppingScreenState extends DeferredState<ShoppingScreen> {
  static ShoppingMode _selectedMode = ShoppingMode.toPurchase;
  static ScheduleFilter _selectedScheduleFilter = ScheduleFilter.all;

  final _jobKey = GlobalKey<HMBDroplistMultiSelectState<Job>>();
  final _searchKey = GlobalKey<HMBSearchState>();
  final _supplierKey = GlobalKey<HMBSelectSupplierState>();
  final _scheduleKey = GlobalKey<HMBDroplistState<ScheduleFilter>>();

  final _taskItems = <TaskItemContext>[];
  List<Job> _selectedJobs = [];
  final selectedSupplier = SelectedSupplier();
  String? filter;

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Shopping');
    await _loadTaskItems();
  }

  bool get _hasAdvancedSelection =>
      selectedSupplier.selected == 0 ||
      _selectedScheduleFilter != ScheduleFilter.all;

  Future<void> _loadTaskItems() async {
    List<TaskItem> items;
    switch (_selectedMode) {
      case ShoppingMode.toPurchase:
        items = await DaoTaskItem().getShoppingItems(
          jobs: _selectedJobs,
          supplierId: selectedSupplier.selected,
        );
      case ShoppingMode.purchased:
        items = await DaoTaskItem().getPurchasedItems(
          since: DateTime.now().subtract(const Duration(days: 1)),
          jobs: _selectedJobs,
          supplierId: selectedSupplier.selected,
        );
      case ShoppingMode.returns:
        items = await DaoTaskItem().getReturnedItems(
          jobs: _selectedJobs,
          supplierId: selectedSupplier.selected,
        );
    }

    _taskItems.clear();
    for (final item in items) {
      final task = await DaoTask().getById(item.taskId);
      final billing = await DaoTask().getBillingTypeByTaskItem(item);
      final returned = await DaoTaskItem().wasReturned(item.id);

      if (!Strings.isBlank(filter) &&
          !item.description.toLowerCase().contains(filter!.toLowerCase())) {
        continue;
      }
      if (_selectedScheduleFilter != ScheduleFilter.all) {
        final job = await DaoJob().getJobForTask(task!.id);
        final next = job == null
            ? null
            : await DaoJobActivity().getNextActivityByJob(job.id);
        if (next == null || !_selectedScheduleFilter.includes(next.start)) {
          continue;
        }
      }
      _taskItems.add(
        TaskItemContext(
          task: task!,
          taskItem: item,
          billingType: billing,
          wasReturned: returned,
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: HMBDroplist<ShoppingMode>(
                        selectedItem: () async => _selectedMode,
                        items: (f) async => ShoppingMode.values,
                        format: (m) => m.displayName,
                        onChanged: (m) async {
                          _selectedMode = m ?? ShoppingMode.toPurchase;
                          await _loadTaskItems();
                        },
                        title: 'View',
                        required: false,
                      ),
                    ),
                    const HMBSpacer(width: true),
                    HMBButtonAdd(
                      onAdd: () async {
                        await showAddItemDialog(context, AddType.shopping);
                        await _loadTaskItems();
                      },
                      enabled: true,
                    ),
                  ],
                ),
                HMBFilterLine(
                  onClearAll: () async {
                    _jobKey.currentState?.clear();
                    // _supplierKey.currentState?.clear();
                    // selectedSupplier
                    //   ..selected = null
                    //   ..setState();
                    _supplierKey.currentState?.clear();
                    _searchKey.currentState?.clear();
                    // _selectedScheduleFilter = ScheduleFilter.all;
                    _scheduleKey.currentState?.clear();
                    await _loadTaskItems();
                    setState(() {});
                  },
                  lineBuilder: (context) => HMBDroplistMultiSelect<Job>(
                    key: _jobKey,
                    initialItems: () async => _selectedJobs,
                    items: (filter) => DaoJob().getActiveJobs(filter),
                    format: (j) => j.summary,

                    onChanged: (list) async {
                      _selectedJobs = list;
                      await _loadTaskItems();
                    },
                    title: 'Jobs',
                    required: false,
                  ),
                  sheetBuilder: (context) => _buildFilters(),
                ),
              ],
            ),
          ),
          Expanded(
            child: DeferredBuilder(
              this,
              builder: (ctx) {
                if (_taskItems.isEmpty) {
                  return const Center(
                    child: Text(
                      'No Shopping Items found\n'
                      '- Shopping items are taken from Task Items\n'
                      '  that are marked as "Materials - buy" or "Tools - buy".\n'
                      "If you were expecting to see items here - check the Job's Status is active.",
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (c, cons) {
                    final isMobile = cons.maxWidth < 900;
                    return isMobile
                        ? ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _taskItems.length,
                            itemBuilder: (c, i) =>
                                _buildShoppingItem(c, _taskItems[i]),
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
                            itemBuilder: (c, i) =>
                                _buildShoppingItem(c, _taskItems[i]),
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

  Widget _buildFilters() => ListView(
    padding: const EdgeInsets.all(16),
    shrinkWrap: true,
    children: [
      Column(
        children: [
          const SizedBox(height: 8),
          HMBSearch(
            key: _searchKey,
            onSearch: (f) async {
              filter = f;
              await _loadTaskItems();
            },
          ),
        ],
      ),

      HMBSelectSupplier(
        key: _supplierKey,
        selectedSupplier: selectedSupplier,
        onSelected: (sup) async {
          selectedSupplier.selected = sup?.id;
          await _loadTaskItems();
        },
      ).help('Filter by Supplier', 'Only show items for the chosen supplier'),
      const SizedBox(height: 16),
      HMBDroplist<ScheduleFilter>(
        key: _scheduleKey,
        selectedItem: () async => _selectedScheduleFilter,
        items: (f) async => ScheduleFilter.values,
        format: (s) => s.displayName,
        onChanged: (sel) async {
          _selectedScheduleFilter = sel ?? ScheduleFilter.all;
          await _loadTaskItems();
        },
        title: 'Schedule',
        required: false,
      ).help(
        'Filter by Schedule',
        'Only show items scheduled in the selected range',
      ),
    ],
  );
  Widget _buildShoppingItem(BuildContext context, TaskItemContext ctx) {
    switch (_selectedMode) {
      case ShoppingMode.toPurchase:
        return ToPurchaseItemCard(itemContext: ctx, onReload: _loadTaskItems);
      case ShoppingMode.purchased:
        return PurchasedItemCard(itemContext: ctx, onReload: _loadTaskItems);
      case ShoppingMode.returns:
        return ReturnItemCard(itemContext: ctx, onReload: _loadTaskItems);
    }
  }
}

Future<List<TaskItemContext>> withContext(List<TaskItem> items) async {
  final out = <TaskItemContext>[];
  for (final i in items) {
    final t = await DaoTask().getById(i.taskId);
    final b = await DaoTask().getBillingTypeByTaskItem(i);
    final r = await DaoTaskItem().wasReturned(i.id);
    out.add(
      TaskItemContext(task: t!, taskItem: i, billingType: b, wasReturned: r),
    );
  }
  return out;
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
    final supplier = itemContext.taskItem.supplierId == null
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
