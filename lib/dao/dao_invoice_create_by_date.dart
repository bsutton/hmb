import 'package:money2/money2.dart';

import '../entity/entity.g.dart';
import '../util/format.dart';
import '../util/local_date.dart';
import '../util/money_ex.dart';
import 'dao_invoice_line.dart';
import 'dao_invoice_line_group.dart';
import 'dao_job.dart';
import 'dao_task.dart';
import 'dao_task_item.dart';
import 'dao_time_entry.dart';

/// This is specifically for Time And Materials Invoicces
Future<Money> createByDate(
  Job job,
  int invoiceId,
  List<int> selectedTaskIds,
) async {
  var totalAmount = MoneyEx.zero;

  /// Determine all of the dates we worked on tasks.
  final workDates = <LocalDate>{};
  final times = await DaoTimeEntry().getByJob(job.id);
  for (final timeEntry in times) {
    if (!selectedTaskIds.contains(times.first.taskId)) {
      continue;
    }

    /// Don't re-bill lines that have already been billed
    if (timeEntry.billed) {
      continue;
    }
    workDates.add(LocalDate.fromDateTime(timeEntry.startTime));
  }

  for (final workDate in workDates) {
    final tasksForDate = TasksForDate(workDate, job, selectedTaskIds);
    await tasksForDate.build();
    var groupCreated = false;

    var totalDurationForDate = Fixed.zero;
    var invoiceLineGroupId = -1;

    for (final taskForDate in tasksForDate.taskForDate) {
      if (taskForDate.durationInHours == Fixed.zero) {
        continue;
      }

      if (!groupCreated) {
        invoiceLineGroupId = await _createInvoiceGroupForDate(
          invoiceId,
          workDate,
        );
        groupCreated = true;
      }

      // Create an invoice line with the total hours in the description
      final invoiceLine = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        description: 'Labour: ${taskForDate.task.name}',
        quantity: taskForDate.durationInHours,
        unitPrice: job.hourlyRate!,
        lineTotal: job.hourlyRate!.multiplyByFixed(taskForDate.durationInHours),
        invoiceLineGroupId: invoiceLineGroupId,
      );

      // Sum the duration for all time entries for the [workDate]
      totalDurationForDate += taskForDate.durationInHours;
      final invoiceLineId = await DaoInvoiceLine().insert(invoiceLine);
      await taskForDate.markBilled(invoiceLineId);
    }

    // Calculate the total line cost
    final lineTotal = job.hourlyRate!.multiplyByFixed(totalDurationForDate);
    if (lineTotal.isZero) {
      continue;
    }

    // Add to the list of grouped lines and update total amount
    totalAmount += lineTotal;
  }
  // Add materials at the end of the invoice, grouped under
  // their respective tasks
  return totalAmount +
      await emitMaterialsByTask(job, invoiceId, selectedTaskIds);
}

Future<int> _createInvoiceGroupForDate(
  int invoiceId,
  LocalDate workDate,
) async {
  final invoiceLineGroup = InvoiceLineGroup.forInsert(
    invoiceId: invoiceId,
    name: formatLocalDate(workDate),
  );
  final invoiceLineGroupId = await DaoInvoiceLineGroup().insert(
    invoiceLineGroup,
  );
  return invoiceLineGroupId;
}

// Add materials at the end of the invoice, grouped under their respective tasks
Future<Money> emitMaterialsByTask(
  Job job,
  int invoiceId,
  List<int> selectedTaskIds,
) async {
  var totalAmount = MoneyEx.zero;

  final hourlyRate = await DaoJob().getHourlyRate(job.id);

  for (final taskId in selectedTaskIds) {
    final task = await DaoTask().getById(taskId);
    final billingType = await DaoTask().getBillingType(task!);
    var groupCreated = false;
    final taskItems = await DaoTaskItem().getByTask(taskId);
    var invoiceLineGroupId = -1;
    for (final item in taskItems) {
      final itemType = TaskItemTypeEnum.fromId(item.itemTypeId);
      if (item.billed ||
          !item.completed ||
          itemType == TaskItemTypeEnum.labour ||
          itemType == TaskItemTypeEnum.toolsOwn ||
          item.getCharge(billingType, hourlyRate) == MoneyEx.zero) {
        continue;
      }

      if (!groupCreated) {
        final task = await DaoTask().getById(taskId);
        final invoiceLineGroup = InvoiceLineGroup.forInsert(
          invoiceId: invoiceId,
          name: 'Materials for ${task!.name}',
        );
        invoiceLineGroupId = await DaoInvoiceLineGroup().insert(
          invoiceLineGroup,
        );
        groupCreated = true;
      }

      final lineTotal = item.actualMaterialUnitCost!.multiplyByFixed(
        item.actualMaterialQuantity!,
      );

      final invoiceLine = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        invoiceLineGroupId: invoiceLineGroupId,
        description: 'Material: ${item.description}',
        quantity: item.actualMaterialQuantity!,
        unitPrice: item.actualMaterialUnitCost!,
        lineTotal: lineTotal,
      );
      final invoiceLineId = await DaoInvoiceLine().insert(invoiceLine);
      await DaoTaskItem().markAsBilled(item, invoiceLineId);

      totalAmount += lineTotal;
    }
  }
  return totalAmount;
}

/// Accumulates all timeentries (that haven't been billed)
/// for the given [date] group by task.
class TasksForDate {
  TasksForDate(this.date, this.job, this.selectedTaskIds);

  Future<void> build() async {
    final tasks = await DaoTask().getTasksByJob(job.id);
    for (final task in tasks) {
      if (!selectedTaskIds.contains(task.id)) {
        continue;
      }

      final taskEntries = TaskEntries(task);
      taskForDate.add(taskEntries);

      final timeEntries = await DaoTimeEntry().getByTask(task.id);
      for (final timeEntry in timeEntries) {
        if (timeEntry.billed) {
          continue;
        }
        if (LocalDate.fromDateTime(timeEntry.startTime) == date) {
          taskEntries.add(timeEntry);
        }
      }
    }
  }

  Job job;
  LocalDate date;
  List<TaskEntries> taskForDate = [];
  List<int> selectedTaskIds;
}

class TaskEntries {
  TaskEntries(this.task);
  Task task;
  final List<TimeEntry> _timeEntries = [];

  Fixed get durationInHours {
    final hours = _timeEntries.fold(
      Duration.zero,
      (sum, value) => sum + value.duration,
    );

    return Fixed.fromNum(hours.inMinutes / 60, decimalDigits: 2);
  }

  void add(TimeEntry timeEntry) => _timeEntries.add(timeEntry);

  Future<void> markBilled(int invoiceLineId) async {
    for (final timeEntry in _timeEntries) {
      await DaoTimeEntry().markAsBilled(timeEntry, invoiceLineId);
    }
  }
}
