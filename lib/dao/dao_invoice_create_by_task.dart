import 'package:money2/money2.dart';

import '../entity/entity.g.dart';
import '../util/util.g.dart';
import 'dao_invoice_line.dart';
import 'dao_invoice_line_group.dart';
import 'dao_task.dart';
import 'dao_task_item.dart';
import 'dao_time_entry.dart';

/// Group by Task then Dates within that task, followed by materials and returns.
Future<Money> createByTask(
  int invoiceId,
  Job job,
  List<int> selectedTaskIds,
) async {
  var totalAmount = MoneyEx.zero;

  // 1. Fetch all tasks for this job
  final tasks = await DaoTask().getTasksByJob(job.id);
  for (final task in tasks) {
    /// Only process tasks that the user selected to be on
    /// this invoice.
    if (!selectedTaskIds.contains(task.id)) {
      continue;
    }

    // 2. Create a new invoice‐line group per task
    final invoiceLineGroup = InvoiceLineGroup.forInsert(
      invoiceId: invoiceId,
      name: task.name,
    );
    final invoiceLineGroupId = await DaoInvoiceLineGroup().insert(
      invoiceLineGroup,
    );

    // 3. Collect labour entries by date for this task
    final labourForDate = await collectLabourPerDay(task);

    // 4. Emit labour (time entries) lines
    if (job.billingType == BillingType.timeAndMaterial) {
      totalAmount += await _timeAndMaterialsLabour(
        labourForDate,
        job,
        invoiceId,
        invoiceLineGroupId,
        task,
      );
    } else {
      totalAmount += await _fixedPriceLabour(
        labourForDate,
        job,
        invoiceId,
        invoiceLineGroupId,
        task,
      );
    }

    // 5. Emit material and return lines
    final taskItems = await DaoTaskItem().getByTask(task.id);
    for (final taskItem in taskItems) {
      if (taskItem.billed || !taskItem.completed) {
        continue;
      }

      final itemType = TaskItemTypeEnum.fromId(taskItem.itemTypeId);
      if (itemType == TaskItemTypeEnum.labour ||
          itemType == TaskItemTypeEnum.toolsOwn) {
        continue;
      }

      // Determine unit cost and quantity based on billing type
      Money unitCost;
      Fixed quantity;
      switch (job.billingType) {
        case BillingType.timeAndMaterial:
          unitCost = taskItem.actualMaterialUnitCost!;
          quantity = taskItem.actualMaterialQuantity!;
        case BillingType.fixedPrice:
          unitCost = taskItem.estimatedMaterialUnitCost!;
          quantity = taskItem.estimatedMaterialQuantity!;
      }

      // Calculate the line total, flipping sign for returns
      var lineTotal = unitCost.multiplyByFixed(quantity);
      if (taskItem.isReturn) {
        lineTotal = -lineTotal;
      }

      final descriptionPrefix = taskItem.isReturn ? 'Returned: ' : 'Material: ';
      final lineDescription = '$descriptionPrefix${taskItem.description}';

      // Insert the invoice line
      final invoiceLine = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        invoiceLineGroupId: invoiceLineGroupId,
        description: lineDescription,
        quantity: quantity,
        unitPrice: unitCost,
        lineTotal: lineTotal,
      );
      final invoiceLineId = await DaoInvoiceLine().insert(invoiceLine);

      // Mark the task item as billed
      await DaoTaskItem().markAsBilled(taskItem, invoiceLineId);

      totalAmount += lineTotal;
    }
  }

  return totalAmount;
}

Future<Money> _timeAndMaterialsLabour(
  List<LabourForTaskOnDate> labourForDate,
  Job job,
  int invoiceId,
  int invoiceLineGroupId,
  Task task,
) async {
  var totalLabourAmount = MoneyEx.zero;
  // Add time entries (labour) grouped by date

  for (final labourForDay in labourForDate) {
    final hoursWorked = labourForDay.durationInHours;
    final lineTotal = job.hourlyRate!.multiplyByFixed(hoursWorked);
    if (lineTotal.isZero) {
      continue;
    }

    final invoiceLine = InvoiceLine.forInsert(
      invoiceId: invoiceId,
      invoiceLineGroupId: invoiceLineGroupId,
      description:
          'Labour: ${task.name} on ${formatLocalDate(labourForDay.date)} — Hours: $hoursWorked',
      quantity: hoursWorked,
      unitPrice: job.hourlyRate!,
      lineTotal: lineTotal,
    );

    final invoiceLineId = await DaoInvoiceLine().insert(invoiceLine);
    totalLabourAmount += lineTotal;

    for (final timeEntry in labourForDay.timeEntries) {
      // Mark time entry as billed with the invoice line id
      await DaoTimeEntry().markAsBilled(timeEntry, invoiceLineId);
    }
  }
  return totalLabourAmount;
}

/// CheckListItems of type [TaskItemTypeEnum.labour] estimates
/// are used on an invoice.
Future<Money> _fixedPriceLabour(
  List<LabourForTaskOnDate> labourForDates,
  Job job,
  int invoiceId,
  int invoiceLineGroupId,
  Task task,
) =>
    // For fixed price, we treat labour the same as time & materials.
    _timeAndMaterialsLabour(
      labourForDates,
      job,
      invoiceId,
      invoiceLineGroupId,
      task,
    );

/// Groups all un‐billed time entries for [task] by date.
Future<List<LabourForTaskOnDate>> collectLabourPerDay(Task task) async {
  final timeEntriesByDate = <LocalDate, List<TimeEntry>>{};
  final timeEntries = await DaoTimeEntry().getByTask(task.id);

  for (final timeEntry in timeEntries.where((entry) => !entry.billed)) {
    final date = LocalDate.fromDateTime(timeEntry.startTime);
    timeEntriesByDate.putIfAbsent(date, () => []).add(timeEntry);
  }

  return timeEntriesByDate.entries
      .map((entry) => LabourForTaskOnDate(task, entry.key, entry.value))
      .toList();
}
