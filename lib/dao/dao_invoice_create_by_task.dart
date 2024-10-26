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

/// Group by Task then Dates within that task, followed by materials
/// associated with that task.
Future<Money> createByTask(
    int invoiceId, Job job, List<int> selectedTaskIds) async {
  var totalAmount = MoneyEx.zero;

  final tasks = await DaoTask().getTasksByJob(job.id);
  for (final task in tasks) {
    /// Only process tasks that the user selected to be on
    /// this invoice.
    if (!selectedTaskIds.contains(task.id)) {
      continue;
    }

    /// A new invoice group for each task.
    final invoiceLineGroup = InvoiceLineGroup.forInsert(
      invoiceId: invoiceId,
      name: task.name,
    );

    final invoiceLineGroupId =
        await DaoInvoiceLineGroup().insert(invoiceLineGroup);

    final labourForDays = await collectLabourPerDay(task);

    // Add time entries (labour) grouped by date
    if (job.billingType == BillingType.timeAndMaterial) {
      totalAmount += await _timeAndMaterialsLabour(
          labourForDays, job, invoiceId, invoiceLineGroupId, task, totalAmount);
    } else {
      totalAmount += await _fixedPriceLabour(
          labourForDays, job, invoiceId, invoiceLineGroupId, task, totalAmount);
    }

    // Add materials
    final checkListItems = await DaoCheckListItem().getByTask(task.id);
    for (final item
        in checkListItems.where((item) => !item.billed && item.completed)) {
      final lineTotal = item.estimatedMaterialUnitCost!
          .multiplyByFixed(item.estimatedMaterialQuantity!);

      final invoiceLine = InvoiceLine.forInsert(
        invoiceId: invoiceId,
        invoiceLineGroupId: invoiceLineGroupId,
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

Future<Money> _timeAndMaterialsLabour(
    List<LabourForTaskOnDate> labourForDays,
    Job job,
    int invoiceId,
    int invoiceLineGroupId,
    Task task,
    Money totalAmount) async {
  // Add time entries (labour) grouped by date
  for (final labourForDay in labourForDays) {
    final lineTotal =
        job.hourlyRate!.multiplyByFixed(labourForDay.durationInHours);

    if (lineTotal.isZero) {
      continue;
    }

    final invoiceLine = InvoiceLine.forInsert(
      invoiceId: invoiceId,
      invoiceLineGroupId: invoiceLineGroupId,
      description:
          'Labour: ${task.name} on ${formatLocalDate(labourForDay.date)} '
          'Hours: ${labourForDay.durationInHours}',
      quantity: labourForDay.durationInHours,
      unitPrice: job.hourlyRate!,
      lineTotal: lineTotal,
    );

    final invoiceLineId = await DaoInvoiceLine().insert(invoiceLine);
    totalAmount += lineTotal;

    for (final timeEntry in labourForDay.timeEntries) {
      // Mark time entry as billed with the invoice line id
      await DaoTimeEntry().markAsBilled(timeEntry, invoiceLineId);
    }
  }
  return totalAmount;
}

/// CheckListItems of type [CheckListItemTypeEnum.labour] estimates
/// are used on an invoice.
Future<Money> _fixedPriceLabour(
    List<LabourForTaskOnDate> labourForDays,
    Job job,
    int invoiceId,
    int invoiceLineGroupId,
    Task task,
    Money totalAmount) async {
  // Add time entries (labour) grouped by date
  for (final labourForDay in labourForDays) {
    final lineTotal =
        job.hourlyRate!.multiplyByFixed(labourForDay.durationInHours);

    if (lineTotal.isZero) {
      continue;
    }

    final invoiceLine = InvoiceLine.forInsert(
      invoiceId: invoiceId,
      invoiceLineGroupId: invoiceLineGroupId,
      description:
          'Labour: ${task.name} on ${formatLocalDate(labourForDay.date)} '
          'Hours: ${labourForDay.durationInHours}',
      quantity: labourForDay.durationInHours,
      unitPrice: job.hourlyRate!,
      lineTotal: lineTotal,
    );

    final invoiceLineId = await DaoInvoiceLine().insert(invoiceLine);
    totalAmount += lineTotal;

    for (final timeEntry in labourForDay.timeEntries) {
      // Mark time entry as billed with the invoice line id
      await DaoTimeEntry().markAsBilled(timeEntry, invoiceLineId);
    }
  }
  return totalAmount;
}

/// Collect the labour for each day [task] was worked on
/// which hasn't yet been billed.
Future<List<LabourForTaskOnDate>> collectLabourPerDay(Task task) async {
  final days = <LabourForTaskOnDate>[];

  // for (final workDate in workDates) {
  //   days.add(await DaoTimeEntry().getLabourForDate(task, workDate));
  // }

  final timeEntries = await DaoTimeEntry().getByTask(task.id);

  // Create a map to group time entries by date
  final timeEntryGroups = <LocalDate, List<TimeEntry>>{};

  for (final timeEntry in timeEntries.where((entry) => !entry.billed)) {
    final date = LocalDate.fromDateTime(timeEntry.startTime);
    timeEntryGroups.putIfAbsent(date, () => []).add(timeEntry);
  }

  /// Sum the hours
  for (final entry in timeEntryGroups.entries) {
    final date = entry.key;
    days.add(LabourForTaskOnDate(task, date, entry.value));
  }

  return days;
}

class LineAndSource {
  LineAndSource({required this.line, this.checkListItem, this.timeEntry});
  InvoiceLine line;
  CheckListItem? checkListItem;
  TimeEntry? timeEntry;

  Future<void> markBilled(int invoiceLineId) async {
    if (checkListItem != null) {
      await DaoCheckListItem().markAsBilled(checkListItem!, invoiceLineId);
    }
    if (timeEntry != null) {
      await DaoTimeEntry().markAsBilled(timeEntry!, invoiceLineId);
    }
  }
}
