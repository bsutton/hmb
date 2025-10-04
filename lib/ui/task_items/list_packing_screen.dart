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
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_job_activity.dart';
import '../../dao/dao_task.dart';
import '../../dao/dao_task_item.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../entity/job_activity.dart';
import '../../entity/job_status.dart';
import '../../entity/task.dart';
import '../../entity/task_item.dart';
import '../../entity/task_item_type.dart';
import '../../util/dart/format.dart';
import '../../util/flutter/app_title.dart';
import '../dialog/add_task_item.dart';
import '../dialog/hmb_comfirm_delete_dialog.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_colours.dart';
import '../widgets/hmb_search.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/hmb_toggle.dart';
import '../widgets/icons/help_button.dart';
import '../widgets/icons/hmb_complete_icon.dart';
import '../widgets/icons/hmb_delete_icon.dart';
import '../widgets/icons/hmb_edit_icon.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/layout/surface.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/select/hmb_filter_line.dart';
import '../widgets/select/hmb_select_job_multi.dart';
import '../widgets/text/hmb_text.dart';
import '../widgets/text/hmb_text_themes.dart';
import 'list_shopping_screen.dart';
import 'mark_as_complete.dart';
import 'shopping_item_dialog.dart';

ScheduleFilter _selectedScheduleFilter = ScheduleFilter.all;

class PackingScreen extends StatefulWidget {
  const PackingScreen({super.key});

  @override
  _PackingScreenState createState() => _PackingScreenState();
}

class TaskItemContext {
  TaskItem taskItem;
  Task task;
  BillingType billingType;
  // If true this item is a return (to supplier) item.
  bool wasReturned;

  TaskItemContext({
    required this.task,
    required this.taskItem,
    required this.billingType,
    required this.wasReturned,
  });
}

class _PackingScreenState extends DeferredState<PackingScreen> {
  final taskItemsContexts = <TaskItemContext>[];

  /// Filters
  List<Job> _selectedJobs = [];
  String? filter;
  var _showPreScheduledJobs = false;
  var _showPreApprovedTasks = false;

  final _scheduleFilterKey = GlobalKey<HMBDroplistState<ScheduleFilter>>();
  @override
  Future<void> asyncInitState() async {
    setAppTitle('Packing List');
    await _loadTaskItems();
  }

  ///
  /// Fetch the list of valid Task Items
  ///
  Future<void> _loadTaskItems() async {
    // Get packing items filtered by the selected jobs.
    final taskItems = await DaoTaskItem().getPackingItems(
      jobs: _selectedJobs,
      showPreScheduledJobs: _showPreScheduledJobs,
      showPreApprovedTask: _showPreApprovedTasks,
    );
    taskItemsContexts.clear();

    for (final taskItem in taskItems) {
      final task = await DaoTask().getById(taskItem.taskId);
      final billingType = await DaoTask().getBillingTypeByTaskItem(taskItem);
      final isReturn = taskItem.isReturn;
      // Apply text filter if present.
      var include =
          Strings.isBlank(filter) ||
          taskItem.description.toLowerCase().contains(filter!.toLowerCase());

      // If a schedule filter is selected (other than "All") check the job's
      //next activity.
      if (include && _selectedScheduleFilter != ScheduleFilter.all) {
        final job = await DaoJob().getJobForTask(task!.id);
        if (job != null) {
          final nextActivity = await DaoJobActivity().getNextActivityByJob(
            job.id,
          );
          include =
              nextActivity != null &&
              _selectedScheduleFilter.includes(
                nextActivity.start,
                now: DateTime.now(),
              );
        } else {
          include = false;
        }
      }

      if (include) {
        taskItemsContexts.add(
          TaskItemContext(
            task: task!,
            taskItem: taskItem,
            billingType: billingType,
            wasReturned: isReturn,
          ),
        );
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HMBColours.background,
    body: Surface(
      child: HMBColumn(
        children: [
          HMBFilterLine(
            lineBuilder: _buildSearchLine,
            sheetBuilder: _buildFilter,
            onReset: () async {
              _selectedJobs.clear();
              _selectedScheduleFilter = ScheduleFilter.all;
              _scheduleFilterKey.currentState?.clear();
              _showPreScheduledJobs = false;
              _showPreApprovedTasks = false;
              await _loadTaskItems();
            },
            isActive: () =>
                _selectedJobs.isNotEmpty ||
                _selectedScheduleFilter != ScheduleFilter.all ||
                !_showPreScheduledJobs ||
                !_showPreApprovedTasks,
          ),
          Expanded(
            child: DeferredBuilder(
              this,
              builder: (context) {
                if (taskItemsContexts.isEmpty) {
                  return _showEmpty();
                }
                return _buildLayout(context);
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildSearchLine(BuildContext context) => HMBSearchWithAdd(
    onSearch: (filter) async {
      this.filter = filter;
      await _loadTaskItems();
    },
    onAdd: () async {
      await showAddItemDialog(context, AddType.packing);
      await _loadTaskItems();
    },
  );

  Widget _buildLayout(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return isMobile
          ? ListView.builder(
              // Mobile layout
              padding: const EdgeInsets.all(8),
              itemCount: taskItemsContexts.length,
              itemBuilder: (context, index) =>
                  _buildListItem(context, taskItemsContexts[index]),
            )
          // Desktop layout
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                mainAxisSpacing: 16, // Added vertical spacing between items
                crossAxisSpacing: 16,
              ),
              itemCount: taskItemsContexts.length,
              itemBuilder: (context, index) =>
                  _buildListItem(context, taskItemsContexts[index]),
            );
    },
  );

  Widget _buildFilter(BuildContext context) => HMBColumn(
    children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HMBSelectJobMulti(
              initialJobs: _selectedJobs,
              onChanged: (selectedJobs) async {
                _selectedJobs = selectedJobs;
                await _loadTaskItems();
              },
            ),
            HMBDroplist<ScheduleFilter>(
              key: _scheduleFilterKey,
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
              '''Filter packing items by job scheduled date (Today, Next 3 Days, or This Week)''',
            ),
            HMBToggle(
              label: 'Show Jobs pre scheduling',
              hint: _preSchedulingHint(),
              initialValue: _showPreScheduledJobs,
              onToggled: (value) async {
                _showPreScheduledJobs = value;
                await _loadTaskItems();
              },
            ),
            HMBToggle(
              label: 'Show Tasks awaiting Approval',
              hint: 'Show Tasks that are marked as  Awaiting Approval',
              initialValue: _showPreApprovedTasks,
              onToggled: (value) async {
                _showPreApprovedTasks = value;
                await _loadTaskItems();
              },
            ),
            const HMBText(
              'Note: Complete, Cancelled and On Hold jobs are not shown',
            ),
          ],
        ),
      ),
    ],
  );

  Center _showEmpty() => Center(
    child: Text('''
No Packing Items found 

- A Job must be Active (Scheduled, In Progress...) for items to appear.
Packing items are taken from Task items that are marked as "${TaskItemType.materialsStock.label}", "${TaskItemType.consumablesStock.label} or  "${TaskItemType.toolsOwn.label}".


'''),
  );
  Widget _buildListItem(
    BuildContext context,
    TaskItemContext itemContext,
  ) => SurfaceCardWithActions(
    height: 250,
    title: itemContext.taskItem.description,
    // tap no longer auto-completes; actions are explicit like the shopping card
    body: Row(
      children: [
        Expanded(
          child: FutureBuilderEx(
            future: JobDetail.get(itemContext.task),
            builder: (context, jobDetail) {
              final jd = jobDetail!;
              return HMBColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HMBTextLine('Customer: ${jd.customer.name}'),
                  HMBTextLine('Job: ${jd.job.summary}'),
                  HMBTextLine('Task: ${itemContext.task.name}'),
                  HMBTextLine('Scheduled: ${jd.dateOfNextActivity()}'),
                  if (itemContext.taskItem.hasDimensions)
                    HMBTextLine(
                      '${itemContext.taskItem.dimension1} '
                      'x ${itemContext.taskItem.dimension2} '
                      'x ${itemContext.taskItem.dimension3} '
                      '${itemContext.taskItem.measurementType}',
                    ),
                  if (itemContext.taskItem.completed)
                    const Text(
                      'Completed',
                      style: TextStyle(color: Colors.green),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
    actions: [
      // Complete
      HMBCompleteIcon(
        onPressed: () async {
          await markAsCompleted(itemContext, context);
          await _loadTaskItems();
        },
      ),
      // Edit (reuse the shopping dialog to edit a TaskItem)
      HMBEditIcon(
        hint: 'Edit Item',
        onPressed: () async {
          await showShoppingItemDialog(context, itemContext, _loadTaskItems);
        },
      ),
      // Delete
      HMBDeleteIcon(
        hint: 'Delete Item',
        onPressed: () async {
          await showConfirmDeleteDialog(
            context: context,
            nameSingular: 'Task Item',
            question:
                'Do you want to delete ${itemContext.taskItem.description}',
            onConfirmed: () async {
              await DaoTaskItem().delete(itemContext.taskItem.id);
              await _loadTaskItems();
              HMBToast.info('Item deleted.');
            },
          );
        },
      ),
    ],
  );

  Future<void> _moveToShoppingList(TaskItemContext itemContext) async {
    final itemType = itemContext.taskItem.itemType;
    // Determine the new item type
    final newType = switch (itemType) {
      TaskItemType.toolsOwn => TaskItemType.toolsBuy,
      TaskItemType.consumablesStock => TaskItemType.consumablesBuy,
      TaskItemType.materialsStock => TaskItemType.materialsBuy,
      _ => null, // Other types are not moved
    };
    if (newType == null) {
      HMBToast.error('Item cannot be moved to shopping list.');
      return;
    }
    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog(itemContext);
    // If the user cancels, do nothing
    if (confirmed != true) {
      return;
    }
    final taskItem = itemContext.taskItem..itemType = newType;
    await DaoTaskItem().update(taskItem);
    await _loadTaskItems();
    HMBToast.info('Item moved to shopping list.');
  }

  Future<bool?> _showConfirmationDialog(TaskItemContext itemContext) async {
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
          HMBButton(
            onPressed: () => Navigator.of(context).pop(false),
            label: 'Cancel',
            hint: "Don't move the item to the shopping list",
          ),
          HMBButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: 'Confirm',
            hint: 'Move the item to the shopping list',
          ),
        ],
      ),
    );
    return confirmed;
  }

  String _preSchedulingHint() {
    final preStartStatuses = JobStatus.preStart();

    final statuses = Strings.conjuctionJoin(
      preStartStatuses.map((status) => status.displayName).toList(),
    );

    return 'Show Jobs that are marked as $statuses';
  }
}

class JobDetail {
  final Job job;
  final JobActivity? nextActivity;
  final Customer customer;

  JobDetail._(this.job, this.nextActivity, this.customer);
  static Future<JobDetail> get(Task task) async {
    final job = await DaoJob().getJobForTask(task.id);
    final nextActivity = await DaoJobActivity().getNextActivityByJob(job!.id);
    final customer = (await DaoCustomer().getByJob(job.id))!;
    return JobDetail._(job, nextActivity, customer);
  }

  String dateOfNextActivity() {
    if (nextActivity == null) {
      return 'Not Scheduled';
    }
    return formatDate(nextActivity!.start);
  }
}
