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

import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:money2/money2.dart';

Future<TimeEntry> createTimeEntry(
  Task task,
  DateTime now,
  Duration duration,
) async {
  // Insert a time entry for the task - 2hrs
  var timeEntry = TimeEntry.forInsert(
    taskId: task.id,
    startTime: now.subtract(duration),
    note: 'Worked on Task 1',
  );
  await DaoTimeEntry().insert(timeEntry);
  timeEntry = timeEntry.copyWith(endTime: timeEntry.startTime.add(duration));
  await DaoTimeEntry().update(timeEntry);

  return timeEntry;
}

Future<Task> createTask(
  Job job,
  String name, {
  BillingType? billingType,
}) async {
  // Insert task for the job
  final task = Task.forInsert(
    jobId: job.id,
    name: name,
    description: 'First task for T&M',
    status: TaskStatus.awaitingApproval,
    billingType: billingType,
  );
  await DaoTask().insert(task);
  return task;
}

Future<TaskItem> insertLabourEstimates(
  Task? task,
  Money labourCost,
  Fixed hours,
) async {
  final labourItem = TaskItem.forInsert(
    taskId: task!.id, // Assuming a check list ID
    description: 'Labour',
    purpose: '',
    itemType: TaskItemType.labour,
    estimatedLabourHours: hours,
    estimatedLabourCost: labourCost,
    margin: Percentage.ten, // 10% margin
    chargeMode: ChargeMode.calculated,
    completed: true,
    measurementType: MeasurementType.length,
    dimension1: Fixed.fromNum(1, decimalDigits: 3),
    dimension2: Fixed.fromNum(1, decimalDigits: 3),
    dimension3: Fixed.fromNum(1, decimalDigits: 3),
    units: Units.m,
    url: 'http://example.com/material',
    labourEntryMode: LabourEntryMode.hours,
  );

  await DaoTaskItem().insert(labourItem);
  return labourItem;
}

Future<TaskItem> insertMaterials(
  Task? task,
  Fixed quantity,
  Money unitCost,
  Percentage margin,
  TaskItemType checkListItemType,
) async {
  final completedMaterialItem = TaskItem.forInsert(
    taskId: task!.id,
    description: 'Completed Material Item',
    purpose: '',
    itemType: checkListItemType,
    estimatedMaterialUnitCost: unitCost,
    estimatedMaterialQuantity: quantity,
    chargeMode: ChargeMode.calculated,
    margin: margin,
    completed: true,
    measurementType: MeasurementType.length,
    dimension1: Fixed.fromNum(1, decimalDigits: 3),
    dimension2: Fixed.fromNum(1, decimalDigits: 3),
    dimension3: Fixed.fromNum(1, decimalDigits: 3),
    units: Units.m,
    url: 'http://example.com/material',
    labourEntryMode: LabourEntryMode.hours,
  );

  await DaoTaskItem().insert(completedMaterialItem);

  return completedMaterialItem;
}

Future<TaskItem> insertMaterialItem(
  Task task, {
  required TaskItemType itemType,
  String description = 'Material Item',
  Fixed? estimatedQuantity,
  Money? estimatedUnitCost,
  Fixed? actualQuantity,
  Money? actualUnitCost,
  Percentage? margin,
  ChargeMode chargeMode = ChargeMode.calculated,
  bool completed = true,
  bool isReturn = false,
}) async {
  final resolvedMargin = margin ?? Percentage.zero;
  final item = TaskItem.forInsert(
    taskId: task.id,
    description: description,
    purpose: '',
    itemType: itemType,
    estimatedMaterialUnitCost: estimatedUnitCost,
    estimatedMaterialQuantity: estimatedQuantity,
    actualMaterialUnitCost: actualUnitCost,
    actualMaterialQuantity: actualQuantity,
    chargeMode: chargeMode,
    margin: resolvedMargin,
    completed: completed,
    measurementType: MeasurementType.length,
    dimension1: Fixed.fromNum(1, decimalDigits: 3),
    dimension2: Fixed.fromNum(1, decimalDigits: 3),
    dimension3: Fixed.fromNum(1, decimalDigits: 3),
    units: Units.m,
    url: 'http://example.com/material',
    labourEntryMode: LabourEntryMode.hours,
    isReturn: isReturn,
  );

  await DaoTaskItem().insert(item);
  return item;
}

Future<Job> createJob(
  DateTime now,
  BillingType billingType, {
  required Money hourlyRate,
  Contact? contact,
  Money? bookingFee,
  String summary = 'Time and Materials Job',
}) async {
  // Insert a job with time and materials billing type
  final job = Job.forInsert(
    customerId: 1, // Assuming a customer ID
    summary: summary,
    description: 'This is a T&M job',
    siteId: 1, // Assuming a site ID
    contactId: contact?.id ?? 1, // Assuming a contact ID
    status: JobStatus.startingStatus, // Assuming a job status ID
    hourlyRate: hourlyRate, // $50 per hour
    bookingFee: bookingFee, // $100 Booking Fee
    billingType: billingType,
    billingContactId: 1, // assumed contact id
  );
  await DaoJob().insert(job);

  return job;
}

Future<Contact> createContact(String firstname, String surname) async {
  final contact = Contact.forInsert(
    firstName: firstname,
    surname: surname,
    mobileNumber: '',
    landLine: '',
    officeNumber: '',
    emailAddress: '',
  );

  await DaoContact().insert(contact);
  return contact;
}
