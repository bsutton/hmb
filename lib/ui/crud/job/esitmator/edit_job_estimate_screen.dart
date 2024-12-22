import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../../../../dao/dao_task.dart';
import '../../../../dao/dao_task_item.dart';
import '../../../../entity/job.dart';
import '../../../../entity/task.dart';
import '../../../../entity/task_item.dart';
import '../../../../entity/task_item_type.dart';
import '../../../../util/money_ex.dart';
import '../../../widgets/async_state.dart';
import '../../../widgets/hmb_button.dart';
import '../../../widgets/hmb_search.dart';
import '../../../widgets/media/photo_gallery.dart';
import '../../../widgets/text/hmb_text_themes.dart';
import '../../check_list/edit_task_item_screen.dart';
import '../../check_list/list_task_item_screen.dart';
import '../../task/edit_task_screen.dart';

class JobEstimateBuilderScreen extends StatefulWidget {
  const JobEstimateBuilderScreen({required this.job, super.key});

  final Job job;

  @override
  _JobEstimateBuilderScreenState createState() =>
      _JobEstimateBuilderScreenState();
}

class _JobEstimateBuilderScreenState
    extends AsyncState<JobEstimateBuilderScreen, void> {
  List<Task> _tasks = [];
  Money _totalLabourCost = MoneyEx.zero;
  Money _totalMaterialsCost = MoneyEx.zero;
  Money _totalCombinedCost = MoneyEx.zero;

  String filter = '';

  @override
  Future<void> asyncInitState() async {
    await _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await DaoTask().getTasksByJob(widget.job.id);
    _tasks = tasks;
    await _calculateTotals();
    setState(() {});
  }

  List<Task> filteredTasks() {
    final filtered = <Task>[];

    if (Strings.isBlank(filter)) {
      return _tasks;
    }
    for (final task in _tasks) {
      if (task.name.toLowerCase().contains(filter) ||
          task.description.toLowerCase().contains(filter)) {
        filtered.add(task);
      }
    }
    return filtered;
  }

  Future<void> _calculateTotals() async {
    var totalLabour = MoneyEx.zero;
    var totalMaterials = MoneyEx.zero;

    for (final task in _tasks) {
      final items = await DaoTaskItem().getByTask(task.id);

      final hourlyRate = await DaoTask().getHourlyRate(task);
      for (final item in items) {
        if (item.itemTypeId == TaskItemTypeEnum.labour.id) {
          totalLabour += item.calcLabourCost(hourlyRate);
        } else {
          final billingType = await DaoTask().getBillingType(task);
          totalMaterials += item.calcMaterialCost(billingType);
        }
      }
    }

    setState(() {
      _totalLabourCost = totalLabour;
      _totalMaterialsCost = totalMaterials;
      _totalCombinedCost = totalLabour + totalMaterials;
    });
  }

  Future<void> _addNewTask() async {
    final newTask = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(job: widget.job),
      ),
    );

    if (newTask != null) {
      await _calculateTotals();
      setState(() {
        _tasks.add(newTask);
      });
    }
  }

  Future<void> _editTask(Task task) async {
    final updatedTask = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(job: widget.job, task: task),
      ),
    );

    if (updatedTask != null) {
      await _calculateTotals();
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
        if (index != -1) {
          _tasks[index] = updatedTask;
        }
      });
    }
  }

  Future<void> _deleteTask(Task task) async {
    await DaoTask().delete(task.id);
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    await _calculateTotals();
  }

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
      future: initialised,
      builder: (context, _) {
        final tasks = filteredTasks();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Estimate Builder'),
          ),
          body: Column(
            children: [
              _buildTotals(),
              HMBSearch(
                  onChanged: (filter) async => setState(() {
                        this.filter = filter ?? '';
                      })),
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildTaskCard(task);
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _addNewTask,
            child: const Icon(Icons.add),
          ),
        );
      });

  Widget _buildTotals() => Card(
        margin: const EdgeInsets.all(8),
        child: ListTile(
          title: const Text('Totals'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Labour: $_totalLabourCost'),
              Text('Materials: $_totalMaterialsCost'),
              Text('Combined: $_totalCombinedCost'),
            ],
          ),
        ),
      );

  Widget _buildTaskCard(Task task) => Card(
        child: Column(
          children: [
            ListTile(
              title: HMBTextHeadline(task.name),
              subtitle: HMBTextHeadline3(task.description),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                onPressed: () async => _deleteTask(task),
              ),
              onTap: () async => _editTask(task),
            ),
            PhotoGallery.forTask(task: task),
            _buildTaskItems(task),
            HMBButton(
              label: 'Add Item',
              onPressed: () async => _addItemToTask(task),
            ),
          ],
        ),
      );

  Widget _buildTaskItems(Task task) => FutureBuilderEx<ItemsAndRate>(
      // ignore: discarded_futures
      future: ItemsAndRate.fromTask(task),
      builder: (context, itemAndRate) => Column(
            children: itemAndRate!.items
                .map((item) => _buildItemTile(item, task,
                    itemAndRate.hourlyRate, itemAndRate.billingType))
                .toList(),
          ));

  Widget _buildItemTile(TaskItem item, Task task, Money hourlyRate,
          BillingType billingType) =>
      ListTile(
        title: Text(item.description),
        subtitle: Text('Cost: ${item.getCharge(billingType, hourlyRate)}'),
        trailing: IconButton(
          icon: const Icon(
            Icons.delete,
            color: Colors.red,
          ),
          onPressed: () async => _deleteItem(item),
        ),
        onTap: () async => _editItem(item, task),
      );

  Future<void> _addItemToTask(Task task) async {
    TaskItem? newItem;

    newItem = await Navigator.of(context).push<TaskItem>(MaterialPageRoute(
        builder: (context) => FutureBuilderEx(
              // ignore: discarded_futures
              future: getTaskAndRate(task),
              builder: (context, taskAndRate) => TaskItemEditScreen(
                parent: task,
                taskItem: newItem,
                billingType:
                    taskAndRate?.billingType ?? BillingType.timeAndMaterial,
                hourlyRate: taskAndRate?.rate ?? MoneyEx.zero,
              ),
            )));
    if (newItem != null) {
      await _calculateTotals();
      setState(() {});
    }
  }

  Future<void> _editItem(TaskItem item, Task task) async {
    final updatedItem = await Navigator.of(context).push<TaskItem>(
      MaterialPageRoute(
        builder: (context) => FutureBuilderEx(
          // ignore: discarded_futures
          future: getTaskAndRate(task),
          builder: (context, taskAndRate) => TaskItemEditScreen(
            parent: task,
            taskItem: item,
            billingType:
                taskAndRate?.billingType ?? BillingType.timeAndMaterial,
            hourlyRate: taskAndRate?.rate ?? MoneyEx.zero,
          ),
        ),
      ),
    );

    if (updatedItem != null) {
      await _calculateTotals();
      setState(() {});
    }
  }

  Future<void> _deleteItem(TaskItem item) async {
    await DaoTaskItem().delete(item.id);
    await _calculateTotals();
    setState(() {});
  }

  Future<TaskAndRate> getTaskAndRate(Task? task) async {
    if (task == null) {
      return TaskAndRate(null, MoneyEx.zero, BillingType.timeAndMaterial);
    }
    return TaskAndRate.fromTask(task);
  }
}

class ItemsAndRate {
  ItemsAndRate(this.items, this.hourlyRate, this.billingType);

  List<TaskItem> items;
  Money hourlyRate;
  BillingType billingType;

  static Future<ItemsAndRate> fromTask(Task task) async {
    final hourlyRate = await DaoTask().getHourlyRate(task);
    final billingType = await DaoTask().getBillingType(task);
    return ItemsAndRate(
        await DaoTaskItem().getByTask(task.id), hourlyRate, billingType);
  }
}
