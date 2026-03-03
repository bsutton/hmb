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
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../../../../api/chat_gpt/job_assist_api_client.dart';
import '../../../../dao/dao.g.dart';
import '../../../../entity/helpers/charge_mode.dart';
import '../../../../entity/job.dart';
import '../../../../entity/task.dart';
import '../../../../entity/task_item.dart';
import '../../../../entity/task_item_type.dart';
import '../../../../entity/task_status.dart';
import '../../../../util/dart/measurement_type.dart';
import '../../../../util/dart/money_ex.dart';
import '../../../../util/dart/units.dart';
import '../../../dialog/hmb_comfirm_delete_dialog.dart';
import '../../../dialog/hmb_dialog.dart';
import '../../../widgets/hmb_button.dart';
import '../../../widgets/hmb_search.dart';
import '../../../widgets/hmb_toast.dart';
import '../../../widgets/hmb_toggle.dart';
import '../../../widgets/icons/hmb_delete_icon.dart';
import '../../../widgets/icons/hmb_edit_icon.dart';
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/layout/surface.dart';
import '../../../widgets/media/photo_gallery.dart';
import '../../../widgets/select/hmb_filter_line.dart';
import '../../../widgets/text/hmb_text_themes.dart';
import '../../check_list/edit_task_item_screen.dart';
import '../../check_list/list_task_item_screen.dart';
import '../../task/edit_task_screen.dart';

enum MarginMode { percent, amount }

class JobEstimateBuilderScreen extends StatefulWidget {
  final Job job;

  const JobEstimateBuilderScreen({required this.job, super.key});

  @override
  _JobEstimateBuilderScreenState createState() =>
      _JobEstimateBuilderScreenState();
}

class _JobEstimateBuilderScreenState
    extends DeferredState<JobEstimateBuilderScreen> {
  List<Task> _tasks = [];
  Money _totalLabourCost = MoneyEx.zero;
  Money _totalMaterialsCost = MoneyEx.zero;
  Money _totalCombinedCost = MoneyEx.zero;
  Percentage _estimateMargin = Percentage.zero;
  var _estimateComplete = false;

  var _showToBeEstimated = true;
  var _showCompleted = false;
  var _showActive = true;
  var _showWithdrawn = false;

  var _filter = '';

  @override
  Future<void> asyncInitState() async {
    final canProceed = await _ensureFixedPrice();
    if (!canProceed) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    final job = await DaoJob().markQuoting(widget.job.id);
    widget.job.status = job.status;
    final refreshedJob = await DaoJob().getById(widget.job.id);
    if (refreshedJob != null) {
      widget.job.estimateMargin = refreshedJob.estimateMargin;
    }
    _estimateMargin = widget.job.estimateMargin;
    await _loadTasks();
  }

  Future<bool> _ensureFixedPrice() async {
    if (widget.job.billingType != BillingType.timeAndMaterial) {
      return true;
    }

    final switchToFixed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estimates Require Fixed Price'),
        content: const Text(
          'You cannot create estimates for Time and Materials jobs. '
          'Switch this job to Fixed Price to continue?',
        ),
        actions: [
          HMBButton(
            label: 'Cancel',
            hint: "Don't switch the job billing type",
            onPressed: () => Navigator.pop(context, false),
          ),
          HMBButton(
            label: 'Switch to Fixed Price',
            hint: 'Update the job to Fixed Price billing',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (switchToFixed != true) {
      return false;
    }

    final updated = widget.job.copyWith(billingType: BillingType.fixedPrice);
    await DaoJob().update(updated);
    widget.job.billingType = updated.billingType;
    return true;
  }

  Future<void> _loadTasks() async {
    _tasks = await DaoTask().getTasksByJob(widget.job.id);

    await _calculateTotals();
    _recomputeEstimateCompletion();
    setState(() {});
  }

  List<Task> filteredTasks() {
    final filtered = _tasks
        .where(
          (task) =>
              _showActive && task.status.isActive() ||
              _showCompleted && task.status.isComplete() ||
              _showToBeEstimated && task.status.toBeEstimated() ||
              _showWithdrawn && task.status.isWithdrawn(),
        )
        .toList();

    if (Strings.isBlank(_filter)) {
      return filtered;
    }
    final normalizedFilter = _filter.toLowerCase();
    return filtered
        .where(
          (task) =>
              task.name.toLowerCase().contains(normalizedFilter) ||
              task.description.toLowerCase().contains(normalizedFilter),
        )
        .toList();
  }

  Future<void> _calculateTotals() async {
    var totalLabour = MoneyEx.zero;
    var totalMaterials = MoneyEx.zero;

    for (final task in _tasks) {
      if (task.status.isWithdrawn()) {
        continue;
      }
      final items = await DaoTaskItem().getByTask(task.id);

      final hourlyRate = await DaoTask().getHourlyRate(task);
      for (final item in items) {
        if (item.itemType == TaskItemType.labour) {
          totalLabour += item.calcLabourCharges(
            task.effectiveBillingType(widget.job.billingType),
            hourlyRate,
          );
        } else {
          final billingType = await DaoTask().getBillingType(task);
          totalMaterials += item.calcMaterialCharges(billingType);
        }
      }
    }

    setState(() {
      _totalLabourCost = totalLabour;
      _totalMaterialsCost = totalMaterials;
      _totalCombinedCost = totalLabour + totalMaterials;
    });
  }

  void _recomputeEstimateCompletion() {
    final estimateTasks = _tasks.where((t) => !t.status.isWithdrawn()).toList();
    _estimateComplete =
        estimateTasks.isNotEmpty &&
        estimateTasks.every((t) => t.status.isComplete());
  }

  Future<void> _addNewTask() async {
    final newTask = await Navigator.of(context).push<Task>(
      MaterialPageRoute(builder: (context) => TaskEditScreen(job: widget.job)),
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
    await showConfirmDeleteDialog(
      context: context,
      nameSingular: 'task',
      question: 'Are you sure you want to delete ${task.name}?',

      onConfirmed: () async {
        try {
          await DaoTask().delete(task.id);
          _tasks.removeWhere((t) => t.id == task.id);
          await _calculateTotals();
          setState(() {});
        } catch (e) {
          HMBToast.error('Unable to delete task: $e');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Estimate Builder',
    child: DeferredBuilder(
      this,
      builder: (context) {
        final tasks = filteredTasks();
        return HMBColumn(
          children: [
            _buildTotals(),
            Surface(
              elevation: SurfaceElevation.e0,
              child: HMBFilterLine(
                lineBuilder: (context) => HMBSearchWithAdd(
                  hint: 'Add Task',
                  onSearch: (filter) => setState(() {
                    _filter = filter ?? '';
                  }),
                  onAdd: _addNewTask,
                ),
                sheetBuilder: (context) => _buildFilter(),
                onReset: () {
                  _showToBeEstimated = true;
                  _showCompleted = false;
                  _showActive = true;
                  _showWithdrawn = false;
                  setState(() {});
                },
                isActive: () =>
                    !_showToBeEstimated ||
                    !_showCompleted ||
                    !_showActive ||
                    !_showWithdrawn,
              ),
            ),
            Expanded(
              child: HMBPadding(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildTaskCard(task);
                  },
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _buildTotals() {
    final marginAmount =
        _totalCombinedCost.plusPercentage(_estimateMargin) - _totalCombinedCost;
    final total = _totalCombinedCost.plusPercentage(_estimateMargin);

    return Surface(
      elevation: SurfaceElevation.e0,
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estimate Complete: ${_estimateComplete ? 'Yes' : 'No'}'),
          Text('Labour: $_totalLabourCost'),
          Text('Materials: $_totalMaterialsCost'),
          Row(
            children: [
              Expanded(child: Text('Margin: $marginAmount ($_estimateMargin)')),
              IconButton(
                tooltip: 'Edit estimate margin',
                onPressed: _showEditMarginDialog,
                icon: const Icon(Icons.edit),
              ),
            ],
          ),
          Text('Total: $total'),
        ],
      ),
    );
  }

  Future<void> _saveEstimateMargin(Percentage parsed) async {
    final updated = widget.job.copyWith(estimateMargin: parsed);
    await DaoJob().update(updated);
    widget.job.estimateMargin = parsed;
    _estimateMargin = parsed;
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _showEditMarginDialog() async {
    final selected = await showDialog<Percentage>(
      context: context,
      builder: (context) => _EstimateMarginDialog(
        initialMargin: _estimateMargin,
        combinedCost: _totalCombinedCost,
      ),
    );

    if (selected == null) {
      return;
    }
    await _saveEstimateMargin(selected);
  }

  Widget _buildTaskCard(Task task) => HMBColumn(
    children: [
      Surface(
        rounded: true,
        elevation: SurfaceElevation.e2,
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: HMBTextHeadline2(task.name)),
                Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Expand with AI',
                      onPressed: () => unawaited(_expandTaskWithAi(task)),
                      icon: const Icon(Icons.auto_awesome),
                    ),
                    HMBEditIcon(
                      onPressed: () => _editTask(task),
                      hint: 'Edit Task',
                    ),
                    HMBDeleteIcon(
                      onPressed: () => _deleteTask(task),
                      hint: 'Delete Task',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 1),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: task.status.isComplete(),
                  onChanged: task.status.isWithdrawn()
                      ? null
                      : (checked) async {
                          await _setTaskCompletion(task, checked ?? false);
                        },
                ),
                const Expanded(
                  child: HMBColumn(
                    spacing: 2,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimate complete for this task'),
                      Text(
                        'Tick when scope and pricing are finalized.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (Strings.isNotBlank(task.description))
              HMBTextBody(task.description),
            PhotoGallery.forTask(task: task),
            _buildTaskItems(task),
            HMBButton(
              label: 'Add Item',
              hint: 'Add an Item (to purchase, pack or labor) to a Task',
              onPressed: () => unawaited(_addItemToTask(task)),
            ),
          ],
        ),
      ),
      const HMBSpacer(height: true),
    ],
  );

  Widget _buildTaskItems(Task task) => FutureBuilderEx<ItemsAndRate>(
    future: ItemsAndRate.fromTask(task),
    builder: (context, itemAndRate) => HMBColumn(
      children: itemAndRate!.items
          .map(
            (item) => _buildItemTile(
              item,
              task,
              itemAndRate.hourlyRate,
              itemAndRate.billingType,
            ),
          )
          .toList(),
    ),
  );

  Widget _buildItemTile(
    TaskItem item,
    Task task,
    Money hourlyRate,
    BillingType billingType,
  ) => Surface(
    rounded: true,
    elevation: SurfaceElevation.e1,
    margin: const EdgeInsets.only(bottom: 8),
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(item.description)),
            HMBEditIcon(
              onPressed: () => _editItem(item, task),
              hint: 'Edit Estimate',
            ),
            HMBDeleteIcon(
              onPressed: () => _deleteItem(item),
              hint: 'Delete Estimate',
            ),
          ],
        ),
        const Divider(height: 1),
        Text('Cost: ${item.getTotalLineCharge(billingType, hourlyRate)}'),
      ],
    ),
  );

  Future<void> _addItemToTask(Task task) async {
    TaskItem? newItem;

    newItem = await Navigator.of(context).push<TaskItem>(
      MaterialPageRoute(
        builder: (context) => FutureBuilderEx(
          future: getTaskAndRate(task),
          builder: (context, taskAndRate) => TaskItemEditScreen(
            parent: task,
            taskItem: newItem,
            billingType:
                taskAndRate?.billingType ?? BillingType.timeAndMaterial,
            hourlyRate: taskAndRate?.rate ?? MoneyEx.zero,
          ),
        ),
      ),
    );
    if (newItem != null) {
      await _calculateTotals();
      setState(() {});
    }
  }

  Future<void> _editItem(TaskItem item, Task task) async {
    final updatedItem = await Navigator.of(context).push<TaskItem>(
      MaterialPageRoute(
        builder: (context) => FutureBuilderEx(
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
    await showConfirmDeleteDialog(
      context: context,
      nameSingular: 'Task item',
      question: 'Are you sure you want to delete ${item.description}?',

      onConfirmed: () async {
        try {
          await DaoTaskItem().delete(item.id);
          await _calculateTotals();
          setState(() {});
        } catch (e) {
          HMBToast.error('Unable to delete item: $e');
        }
      },
    );
  }

  Future<void> _expandTaskWithAi(Task task) async {
    try {
      final suggestions = await JobAssistApiClient().expandTaskToItems(
        jobSummary: widget.job.summary,
        jobDescription: widget.job.description,
        taskName: task.name,
        taskDescription: task.description,
      );
      if (suggestions == null) {
        HMBToast.error('ChatGPT is not configured.');
        return;
      }
      if (suggestions.isEmpty) {
        HMBToast.info('No items were suggested for this task.');
        return;
      }

      var inserted = 0;
      for (final suggestion in suggestions) {
        final item = await _buildTaskItemFromSuggestion(task, suggestion);
        await DaoTaskItem().insert(item);
        inserted++;
      }

      await _calculateTotals();
      setState(() {});
      HMBToast.info('Added $inserted estimate item(s) from AI.');
    } catch (e) {
      HMBToast.error('AI task expansion failed: $e');
    }
  }

  Future<TaskItem> _buildTaskItemFromSuggestion(
    Task task,
    TaskItemAssistSuggestion suggestion,
  ) async {
    final category = suggestion.category.toLowerCase();
    final isLabour = category == 'labour';
    final isTool = category == 'tool';
    final isConsumable = category == 'consumable';

    final qty = suggestion.quantity <= 0 ? 1 : suggestion.quantity;
    final unitCost = suggestion.unitCost < 0 ? 0 : suggestion.unitCost;
    final supplierId = await _findSupplierIdByName(suggestion.supplier);

    return TaskItem.forInsert(
      taskId: task.id,
      description: suggestion.description,
      itemType: isLabour
          ? TaskItemType.labour
          : (isTool
                ? TaskItemType.toolsBuy
                : (isConsumable
                      ? TaskItemType.consumablesBuy
                      : TaskItemType.materialsBuy)),
      margin: Percentage.zero,
      chargeMode: ChargeMode.calculated,
      measurementType: MeasurementType.defaultMeasurementType,
      dimension1: Fixed.zero,
      dimension2: Fixed.zero,
      dimension3: Fixed.zero,
      units: Units.defaultUnits,
      url: '',
      purpose: suggestion.notes,
      labourEntryMode: LabourEntryMode.hours,
      estimatedLabourHours: isLabour
          ? Fixed.fromNum(qty, decimalDigits: 3)
          : null,
      estimatedLabourCost: isLabour && unitCost > 0
          ? Money.fromNum(unitCost * qty, isoCode: 'AUD')
          : null,
      estimatedMaterialUnitCost: isLabour || unitCost <= 0
          ? null
          : Money.fromNum(unitCost, isoCode: 'AUD'),
      estimatedMaterialQuantity: isLabour
          ? null
          : Fixed.fromNum(qty, decimalDigits: 3),
      supplierId: supplierId,
    );
  }

  Future<int?> _findSupplierIdByName(String supplierName) async {
    final name = supplierName.trim();
    if (name.isEmpty) {
      return null;
    }
    final matches = await DaoSupplier().getByFilter(name);
    if (matches.isEmpty) {
      return null;
    }
    for (final supplier in matches) {
      if (supplier.name.trim().toLowerCase() == name.toLowerCase()) {
        return supplier.id;
      }
    }
    return matches.first.id;
  }

  Future<void> _setTaskCompletion(Task task, bool isCompleted) async {
    final previousCompleteState = _estimateComplete;
    final status = isCompleted
        ? TaskStatus.completed
        : TaskStatus.awaitingApproval;
    final updated = task.copyWith(status: status);
    await DaoTask().update(updated);

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = updated;
    }

    _recomputeEstimateCompletion();
    if (!previousCompleteState && _estimateComplete && mounted) {
      HMBToast.info('Estimate marked as complete.');
    }
    setState(() {});
  }

  Future<TaskAndRate> getTaskAndRate(Task? task) async {
    if (task == null) {
      return TaskAndRate(null, MoneyEx.zero, BillingType.timeAndMaterial);
    }
    return TaskAndRate.fromTask(task);
  }

  Future<void> _showFilterHelp({
    required String title,
    required String details,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => HMBDialog(
        title: Text(title),
        content: Text(details),
        actions: [
          HMBButton(
            label: 'Close',
            hint: 'Close filter details',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle({
    required String label,
    required String hint,
    required bool initialValue,
    required OnToggled onToggled,
    required String helpTitle,
    required String helpDetails,
  }) => InkWell(
    onLongPress: () => unawaited(
      _showFilterHelp(title: helpTitle, details: helpDetails),
    ),
    child: HMBToggle(
      label: label,
      hint: hint,
      initialValue: initialValue,
      onToggled: onToggled,
    ),
  );

  Widget _buildFilter() => HMBColumn(
    children: [
      _buildFilterToggle(
        label: 'Show To Be Estimated',
        hint:
            '''Show tasks that can be estimated as they have not started no been cancelled''',
        helpTitle: 'To Be Estimated',
        helpDetails:
            'Shows tasks that still need estimate work. These are tasks '
            'that are not completed and not withdrawn.',
        initialValue: _showToBeEstimated,
        onToggled: (value) {
          _showToBeEstimated = value;
          setState(() {});
        },
      ),
      _buildFilterToggle(
        label: 'Show Complete',
        hint: 'Show tasks that have been completed or cancelled',
        helpTitle: 'Complete',
        helpDetails:
            'Shows tasks marked complete. Use this to review tasks where '
            'estimate scope and pricing are finalized.',
        initialValue: _showCompleted,
        onToggled: (value) {
          _showCompleted = value;
          setState(() {});
        },
      ),
      _buildFilterToggle(
        label: 'Show Active',
        hint: 'Show tasks that currently active',
        helpTitle: 'Active',
        helpDetails:
            'Shows tasks currently in progress. These tasks are active and '
            'not completed or withdrawn.',
        initialValue: _showActive,
        onToggled: (value) {
          _showActive = value;
          setState(() {});
        },
      ),
      _buildFilterToggle(
        label: 'Show Withdrawn',
        hint: 'Show tasks have been cancelled or placed on hold',
        helpTitle: 'Withdrawn',
        helpDetails:
            'Shows tasks removed from estimate workflow, such as cancelled '
            'or on-hold tasks.',
        initialValue: _showWithdrawn,
        onToggled: (value) {
          _showWithdrawn = value;
          setState(() {});
        },
      ),
    ],
  );
}

class _EstimateMarginDialog extends StatefulWidget {
  final Percentage initialMargin;
  final Money combinedCost;

  const _EstimateMarginDialog({
    required this.initialMargin,
    required this.combinedCost,
  });

  @override
  State<_EstimateMarginDialog> createState() => _EstimateMarginDialogState();
}

class _EstimateMarginDialogState extends State<_EstimateMarginDialog> {
  late final TextEditingController _percentController;
  late final TextEditingController _amountController;
  MarginMode _mode = MarginMode.percent;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _percentController = TextEditingController(
      text: widget.initialMargin.toString().replaceAll('%', '').trim(),
    );
    final marginAmount =
        widget.combinedCost.plusPercentage(widget.initialMargin) -
        widget.combinedCost;
    _amountController = TextEditingController(text: marginAmount.toString());
  }

  @override
  void dispose() {
    _percentController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Percentage get _percentValue =>
      Percentage.tryParse(_percentController.text) ??
      Percentage.zero;

  Money get _calculatedAmount =>
      widget.combinedCost.plusPercentage(_percentValue) - widget.combinedCost;

  Percentage get _calculatedPercentFromAmount {
    final normalized = _amountController.text
        .replaceAll(r'$', '')
        .replaceAll(',', '')
        .trim();
    final amountNum = double.tryParse(normalized);
    if (amountNum == null || amountNum < 0 || widget.combinedCost.isZero) {
      return Percentage.zero;
    }
    final amount = Money.fromNum(amountNum, isoCode: 'AUD');
    return Percentage.fromInt(
      ((amount.minorUnits / widget.combinedCost.minorUnits) * 10000).round(),
    );
  }

  void _save() {
    setState(() {
      _validationError = null;
    });

    if (_mode == MarginMode.percent) {
      Navigator.of(context).pop(_percentValue);
      return;
    }

    final normalized = _amountController.text
        .replaceAll(r'$', '')
        .replaceAll(',', '')
        .trim();
    final amountNum = double.tryParse(normalized);
    if (amountNum == null || amountNum < 0) {
      setState(() {
        _validationError = 'Enter a valid non-negative margin amount.';
      });
      return;
    }

    final amount = Money.fromNum(amountNum, isoCode: 'AUD');
    if (widget.combinedCost.isZero && amount.isPositive) {
      setState(() {
        _validationError =
            'Cannot set a dollar margin when total cost is zero.';
      });
      return;
    }

    final percent = widget.combinedCost.isZero
        ? Percentage.zero
        : Percentage.fromInt(
            ((amount.minorUnits / widget.combinedCost.minorUnits) * 10000)
                .round(),
          );
    Navigator.of(context).pop(percent);
  }

  @override
  Widget build(BuildContext context) => HMBDialog(
    title: const Text('Set Estimate Margin'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToggleButtons(
          isSelected: [
            _mode == MarginMode.percent,
            _mode == MarginMode.amount,
          ],
          color: Theme.of(context).colorScheme.onSurface,
          selectedColor: Theme.of(context).colorScheme.onPrimary,
          fillColor: Theme.of(context).colorScheme.primary,
          borderColor: Theme.of(context).colorScheme.outline,
          selectedBorderColor: Theme.of(context).colorScheme.primary,
          onPressed: (index) {
            setState(() {
              _mode = index == 0 ? MarginMode.percent : MarginMode.amount;
              _validationError = null;
            });
          },
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Enter as %'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(r'Enter as $ amount'),
            ),
          ],
        ),
        const HMBSpacer(height: true),
        if (_mode == MarginMode.percent) ...[
          TextField(
            key: const ValueKey('margin_percent_field'),
            controller: _percentController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Margin (%)',
              border: OutlineInputBorder(),
            ),
          ),
          Text('Resulting Margin: $_calculatedAmount'),
        ] else ...[
          TextField(
            key: const ValueKey('margin_amount_field'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: r'Margin ($)',
              border: OutlineInputBorder(),
            ),
          ),
          Text('Resulting Margin %: $_calculatedPercentFromAmount'),
        ],
        if (_validationError != null)
          Text(_validationError!, style: const TextStyle(color: Colors.red)),
      ],
    ),
    actions: [
      HMBButton(
        label: 'Cancel',
        hint: 'Cancel margin changes',
        onPressed: () => Navigator.of(context).pop(),
      ),
      HMBButton(label: 'Save', hint: 'Save estimate margin', onPressed: _save),
    ],
  );
}

class ItemsAndRate {
  List<TaskItem> items;
  Money hourlyRate;
  BillingType billingType;

  ItemsAndRate(this.items, this.hourlyRate, this.billingType);

  static Future<ItemsAndRate> fromTask(Task task) async {
    final hourlyRate = await DaoTask().getHourlyRate(task);
    final billingType = await DaoTask().getBillingType(task);
    return ItemsAndRate(
      await DaoTaskItem().getByTask(task.id),
      hourlyRate,
      billingType,
    );
  }
}
