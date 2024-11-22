import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../../dao/dao_checklist.dart';
import '../../../dao/dao_checklist_item.dart';
import '../../../dao/dao_task.dart';
import '../../../dao/join_adaptors/join_adaptor_check_list_item.dart';
import '../../../entity/check_list.dart';
import '../../../entity/check_list_item.dart';
import '../../../entity/check_list_item_type.dart';
import '../../../entity/job.dart';
import '../../../entity/task.dart';
import '../../../util/money_ex.dart';
import '../../../widgets/async_state.dart';
import '../../../widgets/hmb_button.dart';
import '../../../widgets/media/photo_gallery.dart';
import '../../../widgets/text/hmb_text_themes.dart';
import '../../check_list/edit_checklist_item_screen.dart';
import '../../check_list/list_checklist_item_screen.dart';
import '../../task/edit_task_screen.dart';

class RapidQuoteEntryScreen extends StatefulWidget {
  const RapidQuoteEntryScreen({required this.job, super.key});

  final Job job;

  @override
  _RapidQuoteEntryScreenState createState() => _RapidQuoteEntryScreenState();
}

class _RapidQuoteEntryScreenState
    extends AsyncState<RapidQuoteEntryScreen, void> {
  List<Task> _tasks = [];
  Money _totalLabourCost = MoneyEx.zero;
  Money _totalMaterialsCost = MoneyEx.zero;
  Money _totalCombinedCost = MoneyEx.zero;

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

  Future<void> _calculateTotals() async {
    var totalLabour = MoneyEx.zero;
    var totalMaterials = MoneyEx.zero;

    for (final task in _tasks) {
      final checkList = await DaoCheckList().getByTask(task.id);
      if (checkList != null) {
        final items = await DaoCheckListItem().getByCheckList(checkList);

        final hourlyRate = await DaoTask().getHourlyRate(task);
        for (final item in items) {
          if (item.itemTypeId == CheckListItemTypeEnum.labour.id) {
            totalLabour += item.calcLabourCost(hourlyRate);
          } else {
            totalMaterials += item.calcMaterialCost();
          }
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
      builder: (context, _) => Scaffold(
            appBar: AppBar(
              title: const Text('Rapid Quote Entry'),
            ),
            body: Column(
              children: [
                _buildTotals(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
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
          ));

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
                icon: const Icon(Icons.delete),
                onPressed: () async => _deleteTask(task),
              ),
              onTap: () async => _editTask(task),
            ),
            _buildTaskItems(task),
            PhotoGallery.forTask(task: task),
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
                .map((item) =>
                    _buildItemTile(item, task, itemAndRate.hourlyRate))
                .toList(),
          ));

  Widget _buildItemTile(CheckListItem item, Task task, Money hourlyRate) =>
      ListTile(
        title: Text(item.description),
        subtitle: Text('Cost: ${item.getCharge(hourlyRate)}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async => _deleteItem(item),
        ),
        onTap: () async => _editItem(item, task),
      );

  Future<void> _addItemToTask(Task task) async {
    final checkList = await DaoCheckList().getByTask(task.id);
    if (checkList != null) {
      if (mounted) {
        CheckListItem? newItem;

        newItem =
            await Navigator.of(context).push<CheckListItem>(MaterialPageRoute(
                builder: (context) => FutureBuilderEx(
                      // ignore: discarded_futures
                      future: getTaskAndRate(checkList),
                      builder: (context, taskAndRate) =>
                          CheckListItemEditScreen<CheckList>(
                        daoJoin: JoinAdaptorCheckListCheckListItem(),
                        parent: checkList,
                        checkListItem: newItem,
                        billingType: taskAndRate?.billingType ??
                            BillingType.timeAndMaterial,
                        hourlyRate: taskAndRate?.rate ?? MoneyEx.zero,
                      ),
                    )));
        if (newItem != null) {
          await _calculateTotals();
          setState(() {});
        }
      }
    } else {
      // Create a new checklist for the task
      final newCheckList = CheckList.forInsert(
        name: 'Checklist for ${task.name}',
        description: '',
        listType: CheckListType.owned,
      );
      await DaoCheckList().insert(newCheckList);
      await DaoCheckList().insertForTask(newCheckList, task);
      await _addItemToTask(task);
    }
  }

  Future<void> _editItem(CheckListItem item, Task task) async {
    final checkList = await DaoCheckList().getById(item.checkListId);
    final updatedItem = await Navigator.of(context).push<CheckListItem>(
      MaterialPageRoute(
        builder: (context) => FutureBuilderEx(
          // ignore: discarded_futures
          future: getTaskAndRate(checkList),
          builder: (context, taskAndRate) => CheckListItemEditScreen<Task>(
            daoJoin: JoinAdaptorCheckListCheckListItem(),
            parent: task,
            checkListItem: item,
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

  Future<void> _deleteItem(CheckListItem item) async {
    await DaoCheckListItem().delete(item.id);
    await _calculateTotals();
    setState(() {});
  }

  Future<TaskAndRate> getTaskAndRate(CheckList? checkList) async {
    if (checkList == null) {
      return TaskAndRate(null, MoneyEx.zero, BillingType.timeAndMaterial);
    }
    return TaskAndRate.fromTask(await DaoTask().getTaskForCheckList(checkList));
  }
}

class ItemsAndRate {
  ItemsAndRate(this.items, this.hourlyRate);

  List<CheckListItem> items;
  Money hourlyRate;

  static Future<ItemsAndRate> fromTask(Task task) async {
    final checkList = await DaoCheckList().getByTask(task.id);
    final hourlyRate = await DaoTask().getHourlyRate(task);
    if (checkList != null) {
      return ItemsAndRate(
          await DaoCheckListItem().getByCheckList(checkList), hourlyRate);
    }
    return ItemsAndRate(<CheckListItem>[], hourlyRate);
  }
}
