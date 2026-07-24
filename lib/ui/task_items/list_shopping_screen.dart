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

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/format.dart';
import '../../util/flutter/app_title.dart';
import '../widgets/layout/layout.g.dart';
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
  static ShoppingHistoryRange _selectedHistoryRange =
      ShoppingHistoryRange.last30Days;

  final _jobKey = GlobalKey<HMBSelectJobMultiState>();
  final _searchKey = GlobalKey<HMBSearchState>();
  final _supplierKey = GlobalKey<HMBSelectSupplierState>();
  final _scheduleKey = GlobalKey<HMBDroplistState<ScheduleFilter>>();
  final _historyRangeKey = GlobalKey<HMBDroplistState<ShoppingHistoryRange>>();

  final _taskItems = <_ShoppingItemView>[];
  List<Job> _selectedJobs = [];
  var _showInactiveJobs = false;
  var _loadGeneration = 0;
  var _displayedMode = _selectedMode;
  final selectedSupplier = SelectedSupplier();
  String? filter;

  bool get _isHistoryMode =>
      _selectedMode == ShoppingMode.purchased ||
      _selectedMode == ShoppingMode.returns;

  String get _historyRangeTitle => switch (_selectedMode) {
    ShoppingMode.purchased => 'Purchased in',
    ShoppingMode.returns => 'Returned in',
    ShoppingMode.toPurchase => 'History Range',
  };

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Shopping');
    await _loadTaskItems();
  }

  Future<void> _loadTaskItems() async {
    final generation = ++_loadGeneration;
    final requestedMode = _selectedMode;
    final requestedFilter = filter?.toLowerCase();
    final requestedScheduleFilter = _selectedScheduleFilter;
    List<TaskItem> items;
    switch (requestedMode) {
      case ShoppingMode.toPurchase:
        items = await DaoTaskItem().getShoppingItems(
          jobs: _selectedJobs,
          supplierId: selectedSupplier.selected,
        );
      case ShoppingMode.purchased:
        items = await DaoTaskItem().getPurchasedItems(
          historyRange: _selectedHistoryRange,
          jobs: _selectedJobs,
          supplierId: selectedSupplier.selected,
          includeInactiveJobs: _showInactiveJobs,
        );
      case ShoppingMode.returns:
        items = await DaoTaskItem().getReturnedItems(
          historyRange: _selectedHistoryRange,
          jobs: _selectedJobs,
          supplierId: selectedSupplier.selected,
          includeInactiveJobs: _showInactiveJobs,
        );
    }

    final loaded = await Future.wait(
      items.map(
        (item) => _loadShoppingItem(
          item,
          requestedFilter: requestedFilter,
          requestedScheduleFilter: requestedScheduleFilter,
        ),
      ),
    );
    final loadedItems = loaded.whereType<_ShoppingItemView>().toList();

    if (!mounted || generation != _loadGeneration) {
      return;
    }
    _displayedMode = requestedMode;
    _taskItems
      ..clear()
      ..addAll(loadedItems);
    setState(() {});
  }

  Future<_ShoppingItemView?> _loadShoppingItem(
    TaskItem item, {
    required String? requestedFilter,
    required ScheduleFilter requestedScheduleFilter,
  }) async {
    if (Strings.isNotBlank(requestedFilter) &&
        !item.description.toLowerCase().contains(requestedFilter!)) {
      return null;
    }

    final task = await DaoTask().getById(item.taskId);
    if (task == null) {
      return null;
    }
    if (requestedScheduleFilter != ScheduleFilter.all) {
      final job = await DaoJob().getJobForTask(task.id);
      final next = job == null
          ? null
          : await DaoJobActivity().getNextActivityByJob(job.id);
      if (next == null || !requestedScheduleFilter.includes(next.start)) {
        return null;
      }
    }

    final itemContext = TaskItemContext(
      task: task,
      taskItem: item,
      billingType: await DaoTask().getBillingTypeByTaskItem(item),
      wasReturned: await DaoTaskItem().wasReturned(item.id),
    );
    return _ShoppingItemView(
      itemContext: itemContext,
      details: await CustomerAndJob.fetch(itemContext),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Surface(
      elevation: SurfaceElevation.e0,
      child: HMBColumn(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: HMBColumn(
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
                          if (!_isHistoryMode) {
                            _showInactiveJobs = false;
                          }
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
                  onReset: () async {
                    _jobKey.currentState?.clear();
                    selectedSupplier.selected = null;
                    _searchKey.currentState?.clear();
                    filter = null;
                    _scheduleKey.currentState?.clear();
                    _selectedScheduleFilter = ScheduleFilter.all;
                    _historyRangeKey.currentState?.clear();
                    _selectedHistoryRange = ShoppingHistoryRange.last30Days;
                    _showInactiveJobs = false;
                    _selectedJobs = [];
                    await _loadTaskItems();
                    setState(() {});
                  },
                  isActive: () =>
                      (_jobKey.currentState?.hasSelections() ?? false) ||
                      selectedSupplier.selected != null ||
                      (_scheduleKey.currentState?.hasSelection ?? false) ||
                      _isHistoryMode &&
                          (_selectedHistoryRange !=
                                  ShoppingHistoryRange.last30Days ||
                              _showInactiveJobs) ||
                      Strings.isNotBlank(filter),
                  lineBuilder: (context) => HMBSelectJobMulti(
                    key: _jobKey,
                    initialJobs: _selectedJobs,
                    allowInactiveJobs: _isHistoryMode,
                    showInactiveJobs: _showInactiveJobs,
                    onShowInactiveJobsChanged: (show) async {
                      _showInactiveJobs = show;
                      await _loadTaskItems();
                    },
                    onChanged: (list) async {
                      _selectedJobs = list;
                      await _loadTaskItems();
                    },
                  ),
                  sheetBuilder: (context) => _buildFilters(),
                ),
              ],
            ),
          ),
          Expanded(
            child: DeferredBuilder(
              this,
              waitingBuilder: (context) =>
                  const Center(child: Text('Loading shopping items…')),
              builder: (ctx) {
                if (_taskItems.isEmpty) {
                  return Center(
                    child: Text(
                      'No Shopping Items found\n'
                      '- Shopping items are taken from Task Items\n'
                      '''  that are marked as "${TaskItemType.materialsBuy.label}", "${TaskItemType.toolsBuy.label}", "${TaskItemType.toolsHire.label}" or "${TaskItemType.consumablesBuy.label}".\n'''
                      """If you were expecting to see items here - check the Job's Status is active.""",
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (c, cons) {
                    final isMobile = cons.maxWidth < 900;
                    return isMobile
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                for (final item in _taskItems)
                                  _buildShoppingItem(c, item),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.5,
                                  mainAxisExtent: 352,
                                ),
                            itemCount: _taskItems.length,
                            itemBuilder: (c, i) => Align(
                              alignment: Alignment.topCenter,
                              child: _buildShoppingItem(c, _taskItems[i]),
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

  Widget _buildFilters() => ListView(
    padding: const EdgeInsets.all(16),
    shrinkWrap: true,
    children: [
      HMBColumn(
        children: [
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
      if (_isHistoryMode)
        HMBDroplist<ShoppingHistoryRange>(
          key: _historyRangeKey,
          selectedItem: () async => _selectedHistoryRange,
          items: (filter) async => ShoppingHistoryRange.values,
          format: (range) => range.displayName,
          onChanged: (range) async {
            _selectedHistoryRange = range ?? ShoppingHistoryRange.last30Days;
            await _loadTaskItems();
          },
          title: _historyRangeTitle,
          required: false,
        ).help(
          'Filter by $_historyRangeTitle',
          'Only show purchases and returns modified in the selected range',
        ),
    ],
  );
  Widget _buildShoppingItem(BuildContext context, _ShoppingItemView item) {
    switch (_displayedMode) {
      case ShoppingMode.toPurchase:
        return ToPurchaseItemCard(
          itemContext: item.itemContext,
          details: item.details,
          onReload: _loadTaskItems,
        );
      case ShoppingMode.purchased:
        return PurchasedItemCard(
          itemContext: item.itemContext,
          details: item.details,
          onReload: _loadTaskItems,
        );
      case ShoppingMode.returns:
        return ReturnItemCard(
          itemContext: item.itemContext,
          details: item.details,
          onReload: _loadTaskItems,
        );
    }
  }
}

class _ShoppingItemView {
  final TaskItemContext itemContext;
  final CustomerAndJob details;

  const _ShoppingItemView({required this.itemContext, required this.details});
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
  final Customer customer;
  final Job job;
  final Task task;
  final Supplier? supplier;
  final JobActivity? nextActivity;

  CustomerAndJob._internal(
    this.customer,
    this.job,
    this.task,
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

    return CustomerAndJob._internal(
      customer!,
      job,
      itemContext.task,
      supplier,
      nextActivity,
    );
  }

  String dateOfNextActivity() {
    if (nextActivity == null) {
      return 'Not Scheduled';
    }
    return formatDate(nextActivity!.start);
  }
}
