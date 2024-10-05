import 'package:money2/money2.dart';

import '../entity/_index.g.dart';
import '../util/format.dart';
import '../util/local_date.dart';
import '../util/money_ex.dart';
import 'dao_checklist_item.dart';
import 'dao_invoice_line.dart';
import 'dao_invoice_line_group.dart';
import 'dao_task.dart';
import 'dao_time_entry.dart';

Future<Money> createByDate(
  Job job,
  int invoiceId,
  List<int> selectedTaskIds,
) async {
  var totalAmount = MoneyEx.zero;
  // Prepare containers for grouping
  // final taskGroupMap = <int, List<LineAndSource>>{};
  // final dateGroupedLines = <LineAndSource>[];

  /// Determine all of the dates we worked on tasks.
  final workDates = <LocalDate>{};
  final times = await DaoTimeEntry().getByJob(job.id);
  for (final timeEntry in times) {
    if (!selectedTaskIds.contains(times.first.taskId)) {
      continue;
    }
    workDates.add(LocalDate.fromDateTime(timeEntry.startTime));
  }

  for (final workDate in workDates) {
    final tasksForDate = TasksForDate(workDate, job, selectedTaskIds);

    // TODO(bsutton): don't and a group if no invoice lines are generated.
    /// A new invoice group for each date.
    final invoiceLineGroup = InvoiceLineGroup.forInsert(
      invoiceId: invoiceId,
      name: formatLocalDate(workDate),
    );
    final invoiceLineGroupId =
        await DaoInvoiceLineGroup().insert(invoiceLineGroup);

    var totalDurationForDate = Fixed.zero;

    for (final taskForDate in tasksForDate.taskForDate) {
      if (taskForDate.durationInHours == Fixed.zero) {
        continue;
      }

      // Create an invoice line with the total hours in the description
      final invoiceLine = InvoiceLine.forInsert(
          invoiceId: invoiceId,
          description: 'Labour: ${taskForDate.task.name} - '
              '${taskForDate.durationInHours} hours worked',
          quantity: taskForDate.durationInHours,
          unitPrice: job.hourlyRate!,
          lineTotal:
              job.hourlyRate!.multiplyByFixed(taskForDate.durationInHours),
          invoiceLineGroupId: invoiceLineGroupId);

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

  // // Insert date-based labour lines directly
  // for (final line in dateGroupedLines) {
  //   final invoiceLineId = await DaoInvoiceLine().insert(line.line);
  //   await line.markBilled(invoiceLineId);
  // }

  // // Insert materials grouped by task at the bottom
  // for (final taskLines in taskGroupMap.values) {
  //   for (final line in taskLines) {
  //     final invoiceLineId = await DaoInvoiceLine().insert(line.line);
  //     await line.markBilled(invoiceLineId);
  //   }
  // }
  // Add materials at the end of the invoice, grouped under
  // their respective tasks

  return totalAmount +
      await emitMaterialsByTask(job, invoiceId, selectedTaskIds);
}

// Add materials at the end of the invoice, grouped under their respective tasks
Future<Money> emitMaterialsByTask(
    Job job, int invoiceId, List<int> selectedTaskIds) async {
  var totalAmount = MoneyEx.zero;

  for (final taskId in selectedTaskIds) {
    final checkListItems = await DaoCheckListItem().getByTask(taskId);
    for (final item in checkListItems) {
      if (item.billed || !item.completed) {
        continue;
      }
      final lineTotal = item.estimatedMaterialUnitCost!
          .multiplyByFixed(item.estimatedMaterialQuantity!);

      final invoiceLine = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        description: 'Material: ${item.description}',
        quantity: item.estimatedMaterialQuantity!,
        unitPrice: item.estimatedMaterialUnitCost!,
        lineTotal: lineTotal,
      );
      final invoiceLineId = await DaoInvoiceLine().insert(invoiceLine);
      await DaoCheckListItem().markAsBilled(item, invoiceLineId);

      totalAmount += lineTotal;
    }
  }
  return totalAmount;
}

/// Accumulates all timeentries for the given [date]
/// group by task.
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
    final hours =
        _timeEntries.fold(Duration.zero, (sum, value) => sum + value.duration);

    return Fixed.fromNum(hours.inMinutes / 60, scale: 2);
  }

  void add(TimeEntry timeEntry) => _timeEntries.add(timeEntry);

  Future<void> markBilled(int invoiceLineId) async {
    for (final timeEntry in _timeEntries) {
      await DaoTimeEntry().markAsBilled(timeEntry, invoiceLineId);
    }
  }
}
