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
import '../../entity/task.dart';
import '../../entity/task_item.dart';
import '../../entity/task_item_type.dart';
import '../../util/app_title.dart';
import '../../util/format.dart';
import '../widgets/add_task_item.dart';
import '../widgets/help_button.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_colours.dart';
import '../widgets/hmb_search.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/select/hmb_droplist_multi.dart';
import '../widgets/surface.dart';
import '../widgets/text/hmb_text_themes.dart';
import 'list_shopping_screen.dart';
import 'mark_as_complete.dart';

ScheduleFilter _selectedScheduleFilter = ScheduleFilter.all;

class PackingScreen extends StatefulWidget {
  const PackingScreen({super.key});

  @override
  _PackingScreenState createState() => _PackingScreenState();
}

class TaskItemContext {
  TaskItemContext(this.task, this.taskItem, this.billingType);
  TaskItem taskItem;
  Task task;
  BillingType billingType;
}

class _PackingScreenState extends DeferredState<PackingScreen> {
  final taskItemsContexts = <TaskItemContext>[];
  List<Job> _selectedJobs = [];
  String? filter;

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Packing List');
    await _loadTaskItems();
  }

  Future<void> _loadTaskItems() async {
    // Get packing items filtered by the selected jobs.
    final taskItems = await DaoTaskItem().getPackingItems(jobs: _selectedJobs);
    taskItemsContexts.clear();

    for (final taskItem in taskItems) {
      final task = await DaoTask().getById(taskItem.taskId);
      final billingType = await DaoTask().getBillingTypeByTaskItem(taskItem);
      // Apply text filter if present.
      var include =
          Strings.isBlank(filter) ||
          taskItem.description.toLowerCase().contains(filter!.toLowerCase());

      // If a schedule filter is selected (other than "All") check the job's next activity.
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
        taskItemsContexts.add(TaskItemContext(task!, taskItem, billingType));
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HMBColours.background,
    body: Surface(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HMBSearchWithAdd(
                  onSearch: (filter) async {
                    this.filter = filter;
                    await _loadTaskItems();
                  },
                  onAdd: () async {
                    await showAddItemDialog(context, AddType.packing);
                    await _loadTaskItems();
                  },
                ),
                HMBDroplistMultiSelect<Job>(
                  initialItems: () async => _selectedJobs,
                  items: (filter) async => DaoJob().getActiveJobs(filter),
                  format: (job) => job.summary,
                  onChanged: (selectedJobs) async {
                    _selectedJobs = selectedJobs;
                    await _loadTaskItems();
                  },
                  title: 'Jobs',
                  backgroundColor: SurfaceElevation.e4.color,
                  required: false,
                ).help(
                  'Filter by Job',
                  '''
Allows you to filter the packing list to items from specific Jobs.

If your Job isn't showing then you need to update its status to an Active one such as 'Scheduled, In Progress...' ''',
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
                  'Filter packing items by job scheduled date (Today, Next 3 Days, or This Week)',
                ),
              ],
            ),
          ),
          Expanded(
            child: DeferredBuilder(
              this,
              builder: (context) {
                if (taskItemsContexts.isEmpty) {
                  return _showEmpty();
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 900;
                    return isMobile
                        ? ListView.builder(
                          // Mobile layout
                          padding: const EdgeInsets.all(8),
                          itemCount: taskItemsContexts.length,
                          itemBuilder:
                              (context, index) => _buildListItem(
                                context,
                                taskItemsContexts[index],
                              ),
                        )
                        // Desktop layout
                        : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.5,
                                mainAxisSpacing:
                                    16, // Added vertical spacing between items
                                crossAxisSpacing: 16,
                              ),
                          itemCount: taskItemsContexts.length,
                          itemBuilder:
                              (context, index) => _buildListItem(
                                context,
                                taskItemsContexts[index],
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
No Packing Items found 

- A Job must be Active (Scheduled, In Progress...) for items to appear.
Packing items are taken from Task items that are marked as "Materials - stock" or "Tools - own".


'''),
  );

  Widget _buildListItem(BuildContext context, TaskItemContext itemContext) =>
      SurfaceCard(
        height: 250,
        onPressed: () async => markAsCompleted(itemContext, context),
        title: itemContext.taskItem.description,
        body: Row(
          children: [
            // Constrain details column so buttons are always visible
            Expanded(
              child: FutureBuilderEx(
                // ignore: discarded_futures
                future: JobDetail.get(itemContext.task),
                builder: (context, jobDetail) {
                  final jd = jobDetail!;
                  return Column(
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
            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart, color: Colors.blue),
                  onPressed: () async => _moveToShoppingList(itemContext),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () async => markAsCompleted(itemContext, context),
                ),
              ],
            ),
          ],
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
    final confirmed = await _showConfirmationDialog(itemContext);
    // If the user cancels, do nothing
    if (confirmed != true) {
      return;
    }
    final taskItem = itemContext.taskItem..itemTypeId = newType.id;
    await DaoTaskItem().update(taskItem);
    await _loadTaskItems();
    HMBToast.info('Item moved to shopping list.');
  }

  Future<bool?> _showConfirmationDialog(TaskItemContext itemContext) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Move to Shopping List'),
            content: Text(
              'Are you sure you want to move "${itemContext.taskItem.description}" '
              'to the shopping list?',
            ),
            actions: [
              HMBButton(
                onPressed: () => Navigator.of(context).pop(false),
                label: 'Cancel',
              ),
              HMBButton(
                onPressed: () => Navigator.of(context).pop(true),
                label: 'Confirm',
              ),
            ],
          ),
    );
    return confirmed;
  }
}

class JobDetail {
  JobDetail._(this.job, this.nextActivity, this.customer);
  static Future<JobDetail> get(Task task) async {
    final job = await DaoJob().getJobForTask(task.id);
    final nextActivity = await DaoJobActivity().getNextActivityByJob(job!.id);
    final customer = (await DaoCustomer().getByJob(job.id))!;
    return JobDetail._(job, nextActivity, customer);
  }

  final Job job;
  final JobActivity? nextActivity;
  final Customer customer;

  String dateOfNextActivity() {
    if (nextActivity == null) {
      return 'Not Scheduled';
    }
    return formatDate(nextActivity!.start);
  }
}
