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
import '../util/dart/exceptions.dart';
import '../util/dart/format.dart';
import '../util/dart/local_date.dart';
import '../util/dart/money_ex.dart';
import 'dao.g.dart';

Future<Invoice> createTimeAndMaterialsInvoice(
  Job job,
  Contact billingContact,
  List<int> selectedTaskIds, {
  required bool groupByTask,
  required bool billBookingFee,
}) async {
  if (job.hourlyRate == MoneyEx.zero) {
    throw InvoiceException("Hourly rate must be set for job '${job.summary}'");
  }

  var totalAmount = MoneyEx.zero;

  final system = await DaoSystem().get();
  // Create invoice
  final invoice = Invoice.forInsert(
    jobId: job.id,
    totalAmount: totalAmount,
    dueDate: LocalDate.today().add(Duration(days: system.paymentTermsInDays)),
    billingContactId: billingContact.id,
  );

  final invoiceId = await DaoInvoice().insert(invoice);

  /// Fixed Price invoices don't have a Booking Fee as it is wrapped
  /// up in the total
  if (job.billingType == BillingType.timeAndMaterial) {
    final bookingFee = await DaoJob().getBookingFee(job);

    if (billBookingFee && bookingFee > MoneyEx.zero) {
      final invoiceLineGroup = InvoiceLineGroup.forInsert(
        invoiceId: invoiceId,
        name: 'Booking Fee',
      );
      await DaoInvoiceLineGroup().insert(invoiceLineGroup);

      final invoiceLine = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        invoiceLineGroupId: invoiceLineGroup.id,
        description: 'Booking Fee: ',
        quantity: Fixed.one,
        unitPrice: bookingFee,
        lineTotal: bookingFee,
        fromBookingFee: true,
      );

      job.bookingFeeInvoiced = true;
      await DaoJob().update(job);

      await DaoInvoiceLine().insert(invoiceLine);

      totalAmount += bookingFee;
    }
  }

  totalAmount += await _createInvoiceForSelectedTasks(
    invoiceId,
    job,
    selectedTaskIds,
    groupByTask: groupByTask,
  );

  // Update the invoice total amount
  final updatedInvoice = invoice.copyWith(totalAmount: totalAmount);
  await DaoInvoice().update(updatedInvoice);

  return updatedInvoice;
}

Future<Money> _createInvoiceForSelectedTasks(
  int invoiceId,
  Job job,
  List<int> selectedTaskIds, {
  required bool groupByTask,
}) async {
  var totalAmount = MoneyEx.zero;

  final daoTask = DaoTask();
  final tasks = await daoTask.getTasksByJob(job.id);
  final selectedTasks = tasks
      .where((task) => selectedTaskIds.contains(task.id))
      .toList();

  final fixedTasks = <Task>[];
  final timeAndMaterialsTasks = <Task>[];
  for (final task in selectedTasks) {
    final billingType = await daoTask.getBillingType(task);
    if (billingType == BillingType.nonBillable) {
      continue;
    }
    if (billingType == BillingType.fixedPrice) {
      fixedTasks.add(task);
      continue;
    }
    timeAndMaterialsTasks.add(task);
  }

  for (final task in fixedTasks) {
    totalAmount += await _emitFixedPriceTaskSummary(invoiceId, job, task);
  }

  if (timeAndMaterialsTasks.isEmpty) {
    return totalAmount;
  }

  if (groupByTask) {
    for (final task in timeAndMaterialsTasks) {
      totalAmount += await _emitTimeAndMaterialsLabourByTask(
        invoiceId,
        job,
        task,
      );
    }
  } else {
    totalAmount += await _emitTimeAndMaterialsLabourByDate(
      invoiceId,
      job,
      timeAndMaterialsTasks,
    );
  }

  return totalAmount +
      await _emitTimeAndMaterialsMaterials(invoiceId, timeAndMaterialsTasks);
}

Future<Money> _emitFixedPriceTaskSummary(
  int invoiceId,
  Job job,
  Task task,
) async {
  final daoTaskItem = DaoTaskItem();
  final daoInvoiceLine = DaoInvoiceLine();

  var total = MoneyEx.zero;
  final billableItems = <TaskItem>[];
  final taskItems = await daoTaskItem.getByTask(task.id);
  final hourlyRate = job.hourlyRate ?? MoneyEx.zero;

  for (final item in taskItems) {
    if (item.billed || !item.completed) {
      continue;
    }

    if (item.itemType == TaskItemType.toolsOwn) {
      continue;
    }

    final lineCharge = item.getTotalLineCharge(
      BillingType.fixedPrice,
      hourlyRate,
    );
    if (lineCharge.isZero) {
      continue;
    }

    billableItems.add(item);
    total += lineCharge;
  }

  if (total.isZero) {
    return MoneyEx.zero;
  }

  final invoiceLineGroup = InvoiceLineGroup.forInsert(
    invoiceId: invoiceId,
    name: task.name,
  );
  final invoiceLineGroupId = await DaoInvoiceLineGroup().insert(
    invoiceLineGroup,
  );
  final invoiceLine = InvoiceLine.forInsert(
    invoiceId: invoiceId,
    invoiceLineGroupId: invoiceLineGroupId,
    description: 'Task: ${task.name}',
    quantity: Fixed.one,
    unitPrice: total,
    lineTotal: total,
  );
  final invoiceLineId = await daoInvoiceLine.insert(invoiceLine);

  for (final item in billableItems) {
    await daoTaskItem.markAsBilled(item, invoiceLineId);
  }

  return total;
}

Future<Money> _emitTimeAndMaterialsLabourByTask(
  int invoiceId,
  Job job,
  Task task,
) async {
  final timeEntries = await DaoTimeEntry().getByTask(task.id);
  final unbilledEntries = timeEntries.where((entry) => !entry.billed).toList();
  if (unbilledEntries.isEmpty) {
    return MoneyEx.zero;
  }

  final totalDuration = unbilledEntries.fold(
    Duration.zero,
    (sum, entry) => sum + entry.duration,
  );
  final totalHours = Fixed.fromNum(
    totalDuration.inMinutes / 60,
    decimalDigits: 2,
  );
  if (totalHours.isZero) {
    return MoneyEx.zero;
  }

  final invoiceLineGroup = InvoiceLineGroup.forInsert(
    invoiceId: invoiceId,
    name: task.name,
  );
  final invoiceLineGroupId = await DaoInvoiceLineGroup().insert(
    invoiceLineGroup,
  );
  final lineTotal = job.hourlyRate!.multiplyByFixed(totalHours);
  final labourLine = InvoiceLine.forInsert(
    invoiceId: invoiceId,
    invoiceLineGroupId: invoiceLineGroupId,
    description: 'Labour: ${task.name}',
    quantity: totalHours,
    unitPrice: job.hourlyRate!,
    lineTotal: lineTotal,
  );
  final invoiceLineId = await DaoInvoiceLine().insert(labourLine);
  for (final entry in unbilledEntries) {
    await DaoTimeEntry().markAsBilled(entry, invoiceLineId);
  }

  return lineTotal;
}

Future<Money> _emitTimeAndMaterialsLabourByDate(
  int invoiceId,
  Job job,
  List<Task> tasks,
) async {
  final entriesByDate = <LocalDate, List<TimeEntry>>{};
  for (final task in tasks) {
    final timeEntries = await DaoTimeEntry().getByTask(task.id);
    for (final entry in timeEntries.where((timeEntry) => !timeEntry.billed)) {
      final workDate = LocalDate.fromDateTime(entry.startTime);
      entriesByDate.putIfAbsent(workDate, () => []).add(entry);
    }
  }

  var totalAmount = MoneyEx.zero;
  final sortedDates = entriesByDate.keys.toList()
    ..sort((lhs, rhs) => lhs.date.compareTo(rhs.date));
  for (final date in sortedDates) {
    final entries = entriesByDate[date] ?? <TimeEntry>[];
    final totalDuration = entries.fold(
      Duration.zero,
      (sum, entry) => sum + entry.duration,
    );
    final totalHours = Fixed.fromNum(
      totalDuration.inMinutes / 60,
      decimalDigits: 2,
    );
    if (totalHours.isZero) {
      continue;
    }

    final invoiceLineGroup = InvoiceLineGroup.forInsert(
      invoiceId: invoiceId,
      name: formatLocalDate(date),
    );
    final invoiceLineGroupId = await DaoInvoiceLineGroup().insert(
      invoiceLineGroup,
    );
    final lineTotal = job.hourlyRate!.multiplyByFixed(totalHours);
    final labourLine = InvoiceLine.forInsert(
      invoiceId: invoiceId,
      invoiceLineGroupId: invoiceLineGroupId,
      description: 'Labour',
      quantity: totalHours,
      unitPrice: job.hourlyRate!,
      lineTotal: lineTotal,
    );
    final invoiceLineId = await DaoInvoiceLine().insert(labourLine);
    for (final entry in entries) {
      await DaoTimeEntry().markAsBilled(entry, invoiceLineId);
    }

    totalAmount += lineTotal;
  }

  return totalAmount;
}

Future<Money> _emitTimeAndMaterialsMaterials(
  int invoiceId,
  List<Task> tasks,
) async {
  final daoTaskItem = DaoTaskItem();
  final daoInvoiceLine = DaoInvoiceLine();
  var totalAmount = MoneyEx.zero;

  for (final task in tasks) {
    var groupId = -1;
    var groupCreated = false;

    final taskItems = await daoTaskItem.getByTask(task.id);
    for (final item in taskItems) {
      if (item.billed ||
          !item.completed ||
          item.itemType == TaskItemType.labour) {
        continue;
      }

      final calculator = item.calcMaterialCost(BillingType.timeAndMaterial);
      if (calculator.lineChargeTotal.isZero) {
        continue;
      }

      if (!groupCreated) {
        final invoiceLineGroup = InvoiceLineGroup.forInsert(
          invoiceId: invoiceId,
          name: 'Materials for ${task.name}',
        );
        groupId = await DaoInvoiceLineGroup().insert(invoiceLineGroup);
        groupCreated = true;
      }

      final descriptionPrefix = item.isReturn
          ? 'Returned: '
          : item.itemType == TaskItemType.toolsOwn
          ? 'Tool hire: '
          : 'Material: ';
      final line = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        invoiceLineGroupId: groupId,
        description: '$descriptionPrefix${item.description}',
        quantity: calculator.quantity,
        unitPrice: calculator.calculatedUnitCharge,
        lineTotal: calculator.lineChargeTotal,
      );
      final invoiceLineId = await daoInvoiceLine.insert(line);
      await daoTaskItem.markAsBilled(item, invoiceLineId);
      totalAmount += calculator.lineChargeTotal;
    }
  }

  return totalAmount;
}
