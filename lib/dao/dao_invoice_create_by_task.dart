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

import 'package:money2/money2.dart';

import '../entity/entity.g.dart';
import '../entity/helpers/material_calculator.dart';
import '../util/dart/dart.g.dart';
import 'dao_invoice_line.dart';
import 'dao_invoice_line_group.dart';
import 'dao_task.dart';
import 'dao_task_item.dart';
import 'dao_time_entry.dart';

/// Group by Task then Dates within that task,
///  followed by materials and returns.
Future<Money> createInvoiceForTasks(
  int invoiceId,
  Job job,
  List<int> selectedTaskIds,
) => job.billingType == BillingType.fixedPrice
    ? _createFixedPriceInvoiceForTasks(invoiceId, job, selectedTaskIds)
    : _createTimeAndMaterialsInvoiceForTasks(invoiceId, job, selectedTaskIds);

Future<Money> _createTimeAndMaterialsInvoiceForTasks(
  int invoiceId,
  Job job,
  List<int> selectedTaskIds,
) async {
  var totalAmount = MoneyEx.zero;

  // 1. Fetch all tasks for this job
  final daoTask = DaoTask();
  final daoTaskItem = DaoTaskItem();
  final daoInvoiceLine = DaoInvoiceLine();
  final daoInvoiceLineGroup = DaoInvoiceLineGroup();

  final tasks = await daoTask.getTasksByJob(job.id);
  for (final task in tasks) {
    /// Only process tasks that the user selected to be on
    /// this invoice.
    if (!selectedTaskIds.contains(task.id)) {
      continue;
    }

    final taskBillingType = await daoTask.getBillingType(task);
    if (taskBillingType == BillingType.nonBillable) {
      continue;
    }

    // 2. Create a new invoice‐line group per task
    final invoiceLineGroup = InvoiceLineGroup.forInsert(
      invoiceId: invoiceId,
      name: task.name,
    );
    final invoiceLineGroupId = await daoInvoiceLineGroup.insert(
      invoiceLineGroup,
    );

    // 3. Emit labour lines
    if (taskBillingType == BillingType.timeAndMaterial) {
      final labourForDate = await collectLabourPerDay(task);
      totalAmount += await _timeAndMaterialsLabour(
        labourForDate,
        job,
        invoiceId,
        invoiceLineGroupId,
        task,
      );
    }

    // 5. Emit material and return lines
    final taskItems = await daoTaskItem.getByTask(task.id);
    for (final taskItem in taskItems) {
      if (taskItem.billed || !taskItem.completed) {
        continue;
      }

      final itemType = taskItem.itemType;
      if (itemType == TaskItemType.toolsOwn &&
          taskBillingType != BillingType.timeAndMaterial) {
        // For fixed price tasks we skip tools owned by us.
        continue;
      }

      if (itemType == TaskItemType.labour) {
        if (taskBillingType != BillingType.fixedPrice) {
          continue;
        }

        final hourlyRate = job.hourlyRate ?? MoneyEx.zero;
        final labourTotal = taskItem.getTotalLineCharge(
          taskBillingType,
          hourlyRate,
        );
        if (labourTotal.isZero) {
          continue;
        }

        var quantity = taskItem.estimatedLabourHours ?? Fixed.zero;
        if (taskItem.labourEntryMode != LabourEntryMode.hours ||
            quantity.isZero) {
          quantity = Fixed.one;
        }
        final unitPrice = labourTotal.divideByFixed(quantity);

        final labourLine = InvoiceLine.forInsert(
          invoiceId: invoiceId,
          invoiceLineGroupId: invoiceLineGroupId,
          description: 'Labour: ${taskItem.description}',
          quantity: quantity,
          unitPrice: unitPrice,
          lineTotal: labourTotal,
        );
        final invoiceLineId = await daoInvoiceLine.insert(labourLine);
        await daoTaskItem.markAsBilled(taskItem, invoiceLineId);
        totalAmount += labourTotal;
        continue;
      }

      // Determine unit cost and quantity based on billing type
      final calculator = MaterialCalculator(taskBillingType, taskItem);
      if (itemType == TaskItemType.toolsOwn &&
          taskBillingType == BillingType.timeAndMaterial &&
          calculator.lineChargeTotal.isZero) {
        // T&M: tools owned by us can be billed as a hire charge
        // when a non-zero charge is specified.
        continue;
      }

      final descriptionPrefix = taskItem.isReturn
          ? 'Returned: '
          : (itemType == TaskItemType.toolsOwn
                ? 'Tool hire: '
                : 'Material: ');
      final lineDescription = '$descriptionPrefix${taskItem.description}';

      // Insert the invoice line
      final invoiceLine = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        invoiceLineGroupId: invoiceLineGroupId,
        description: lineDescription,
        quantity: calculator.quantity,
        unitPrice: calculator.calculatedUnitCharge,
        lineTotal: calculator.lineChargeTotal,
      );
      final invoiceLineId = await daoInvoiceLine.insert(invoiceLine);

      // Mark the task item as billed
      await daoTaskItem.markAsBilled(taskItem, invoiceLineId);

      totalAmount += invoiceLine.lineTotal;
    }
  }

  return totalAmount;
}

Future<Money> _createFixedPriceInvoiceForTasks(
  int invoiceId,
  Job job,
  List<int> selectedTaskIds,
) async {
  var totalAmount = MoneyEx.zero;

  final daoTask = DaoTask();
  final daoTaskItem = DaoTaskItem();
  final daoInvoiceLine = DaoInvoiceLine();
  final daoInvoiceLineGroup = DaoInvoiceLineGroup();

  final tasks = await daoTask.getTasksByJob(job.id);
  for (final task in tasks) {
    if (!selectedTaskIds.contains(task.id)) {
      continue;
    }

    final taskBillingType = await daoTask.getBillingType(task);
    if (taskBillingType == BillingType.nonBillable) {
      continue;
    }

    final invoiceLineGroup = InvoiceLineGroup.forInsert(
      invoiceId: invoiceId,
      name: task.name,
    );
    final invoiceLineGroupId = await daoInvoiceLineGroup.insert(
      invoiceLineGroup,
    );

    // Labour: time entries only for T&M tasks.
    if (taskBillingType == BillingType.timeAndMaterial) {
      final labourForDate = await collectLabourPerDay(task);
      totalAmount += await _timeAndMaterialsLabour(
        labourForDate,
        job,
        invoiceId,
        invoiceLineGroupId,
        task,
      );
    }

    final taskItems = await daoTaskItem.getByTask(task.id);
    for (final taskItem in taskItems) {
      if (taskItem.billed || !taskItem.completed) {
        continue;
      }

      final itemType = taskItem.itemType;
      if (itemType == TaskItemType.toolsOwn &&
          taskBillingType != BillingType.timeAndMaterial) {
        // For fixed price tasks we skip tools owned by us.
        continue;
      }

      if (itemType == TaskItemType.labour) {
        if (taskBillingType != BillingType.fixedPrice) {
          continue;
        }

        final hourlyRate = job.hourlyRate ?? MoneyEx.zero;
        final labourTotal = taskItem.getTotalLineCharge(
          taskBillingType,
          hourlyRate,
        );
        if (labourTotal.isZero) {
          continue;
        }

        var quantity = taskItem.estimatedLabourHours ?? Fixed.zero;
        if (taskItem.labourEntryMode != LabourEntryMode.hours ||
            quantity.isZero) {
          quantity = Fixed.one;
        }
        final unitPrice = labourTotal.divideByFixed(quantity);

        final labourLine = InvoiceLine.forInsert(
          invoiceId: invoiceId,
          invoiceLineGroupId: invoiceLineGroupId,
          description: 'Labour: ${taskItem.description}',
          quantity: quantity,
          unitPrice: unitPrice,
          lineTotal: labourTotal,
        );
        final invoiceLineId = await daoInvoiceLine.insert(labourLine);
        await daoTaskItem.markAsBilled(taskItem, invoiceLineId);
        totalAmount += labourTotal;
        continue;
      }

      final calculator = MaterialCalculator(taskBillingType, taskItem);
      if (itemType == TaskItemType.toolsOwn &&
          taskBillingType == BillingType.timeAndMaterial &&
          calculator.lineChargeTotal.isZero) {
        // T&M: tools owned by us can be billed as a hire charge
        // when a non-zero charge is specified.
        continue;
      }

      final descriptionPrefix = taskItem.isReturn
          ? 'Returned: '
          : (itemType == TaskItemType.toolsOwn
                ? 'Tool hire: '
                : 'Material: ');
      final lineDescription = '$descriptionPrefix${taskItem.description}';

      final invoiceLine = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        invoiceLineGroupId: invoiceLineGroupId,
        description: lineDescription,
        quantity: calculator.quantity,
        unitPrice: calculator.calculatedUnitCharge,
        lineTotal: calculator.lineChargeTotal,
      );
      final invoiceLineId = await daoInvoiceLine.insert(invoiceLine);

      await daoTaskItem.markAsBilled(taskItem, invoiceLineId);

      totalAmount += invoiceLine.lineTotal;
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
          '''Labour: ${task.name} on ${formatLocalDate(labourForDay.date)} — Hours: $hoursWorked''',
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
