/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

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

/// This is specifically for Time And Materials Invoices
Future<Money> createByDate(
  Job job,
  int invoiceId,
  List<int> selectedTaskIds,
) async {
  var totalAmount = MoneyEx.zero;

  // Determine all of the dates we worked on tasks.
  final workDates = <LocalDate>{};
  final times = await DaoTimeEntry().getByJob(job.id);
  for (final timeEntry in times) {
    if (!selectedTaskIds.contains(timeEntry.taskId)) {
      continue;
    }
    if (timeEntry.billed) {
      continue;
    }
    workDates.add(LocalDate.fromDateTime(timeEntry.startTime));
  }

  // Build time-based lines
  for (final workDate in workDates) {
    final tasksForDate = TasksForDate(workDate, job, selectedTaskIds);
    await tasksForDate.build();
    var groupCreated = false;

    var totalDurationForDate = Fixed.zero;
    var invoiceLineGroupId = -1;

    for (final taskForDate in tasksForDate.taskForDate) {
      final duration = taskForDate.durationInHours;
      if (duration == Fixed.zero) {
        continue;
      }

      if (!groupCreated) {
        invoiceLineGroupId = await createInvoiceGroupForDate(
          invoiceId,
          workDate,
        );
        groupCreated = true;
      }

      // Create an invoice line with the total labour hours in the description
      final lineTotal = job.hourlyRate!.multiplyByFixed(duration);
      final invoiceLine = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        description: 'Labour: ${taskForDate.task.name}',
        quantity: duration,
        unitPrice: job.hourlyRate!,
        lineTotal: lineTotal,
        invoiceLineGroupId: invoiceLineGroupId,
      );
      // Sum the duration for all time entries for the [workDate]
      totalDurationForDate += duration;
      final invoiceLineId = await DaoInvoiceLine().insert(invoiceLine);
      await taskForDate.markBilled(invoiceLineId);
    }

    // Sum total costs up for the date
    final lineTotal = job.hourlyRate!.multiplyByFixed(totalDurationForDate);
    if (lineTotal.isZero) {
      continue;
    }

    // Add to the list of grouped lines and update total amount
    totalAmount += lineTotal;
  }
  // Add materials (and returns) at the end of the invoice
  return totalAmount +
      await emitMaterialsByTask(job, invoiceId, selectedTaskIds);
}

Future<int> createInvoiceGroupForDate(int invoiceId, LocalDate workDate) {
  final invoiceLineGroup = InvoiceLineGroup.forInsert(
    invoiceId: invoiceId,
    name: formatLocalDate(workDate),
  );
  return DaoInvoiceLineGroup().insert(invoiceLineGroup);
}

/// Add materials (and returns) at the end of the invoice, grouped under their respective tasks
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
      // skip time entries, tools-own, zero-charge, uncompleted or already billed
      if (item.billed ||
          !item.completed ||
          itemType == TaskItemTypeEnum.labour ||
          itemType == TaskItemTypeEnum.toolsOwn ||
          item.getCharge(billingType, hourlyRate) == MoneyEx.zero) {
        continue;
      }

      // first material/return line for this task: create group
      if (!groupCreated) {
        final invoiceLineGroup = InvoiceLineGroup.forInsert(
          invoiceId: invoiceId,
          name: 'Materials for ${task.name}',
        );
        invoiceLineGroupId = await DaoInvoiceLineGroup().insert(
          invoiceLineGroup,
        );
        groupCreated = true;
      }

      // compute line total; flip sign if this is a return
      var lineTotal = item.actualMaterialUnitCost!.multiplyByFixed(
        item.actualMaterialQuantity!,
      );
      if (item.isReturn) {
        lineTotal = -lineTotal;
      }

      final description = item.isReturn
          ? 'Returned: ${item.description}'
          : 'Material: ${item.description}';

      final invoiceLine = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        invoiceLineGroupId: invoiceLineGroupId,
        description: description,
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
/// for the given [date], grouped by task.
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

  final Job job;
  final LocalDate date;
  final taskForDate = <TaskEntries>[];
  final List<int> selectedTaskIds;
}

class TaskEntries {
  TaskEntries(this.task);
  final Task task;
  final _timeEntries = <TimeEntry>[];

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
