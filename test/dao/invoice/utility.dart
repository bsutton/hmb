import 'package:hmb/dao/_index.g.dart';
import 'package:hmb/dao/dao_task_item.dart';
import 'package:hmb/entity/_index.g.dart';
import 'package:hmb/entity/task_item.dart';
import 'package:hmb/util/measurement_type.dart';
import 'package:hmb/util/percentage.dart';
import 'package:hmb/util/units.dart';
import 'package:money2/money2.dart';

Future<TimeEntry> createTimeEntry(
    Task task, DateTime now, Duration duration) async {
  // Insert a time entry for the task - 2hrs
  var timeEntry = TimeEntry.forInsert(
      taskId: task.id,
      startTime: now.subtract(duration),
      note: 'Worked on Task 1');
  await DaoTimeEntry().insert(timeEntry);
  timeEntry = timeEntry.copyWith(endTime: timeEntry.startTime.add(duration));
  await DaoTimeEntry().update(timeEntry);

  return timeEntry;
}

Future<Task> createTask(Job job, String name) async {
  // Insert task for the job
  final task = Task.forInsert(
    jobId: job.id,
    name: name,
    description: 'First task for T&M',
    taskStatusId: TaskStatusEnum.preApproval.index,
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
    itemTypeId: (await DaoTaskItemType().getLabour()).id,
    estimatedMaterialUnitCost: null,
    estimatedMaterialQuantity: null,
    estimatedLabourHours: hours,
    estimatedLabourCost: labourCost,
    charge: null,
    margin: Percentage.ten, // 10% margin
    completed: true,
    measurementType: MeasurementType.length,
    dimension1: Fixed.fromNum(1, scale: 3),
    dimension2: Fixed.fromNum(1, scale: 3),
    dimension3: Fixed.fromNum(1, scale: 3),
    units: Units.m,
    url: 'http://example.com/material',
    labourEntryMode: LabourEntryMode.hours,
  );

  await DaoTaskItem().insert(labourItem);
  return labourItem;
}

Future<TaskItem> insertMaterials(Task? task, Fixed quantity, Money unitCost,
    Percentage margin, TaskItemType checkListItemType) async {
  final completedMaterialItem = TaskItem.forInsert(
    taskId: task!.id,
    description: 'Completed Material Item',
    itemTypeId: checkListItemType.id,
    estimatedMaterialUnitCost: unitCost,
    estimatedMaterialQuantity: quantity,
    estimatedLabourCost: null,
    estimatedLabourHours: null,
    margin: margin,
    charge: null,
    completed: true,
    measurementType: MeasurementType.length,
    dimension1: Fixed.fromNum(1, scale: 3),
    dimension2: Fixed.fromNum(1, scale: 3),
    dimension3: Fixed.fromNum(1, scale: 3),
    units: Units.m,
    url: 'http://example.com/material',
    labourEntryMode: LabourEntryMode.hours,
  );

  await DaoTaskItem().insert(completedMaterialItem);

  return completedMaterialItem;
}

Future<Job> createJob(DateTime now, BillingType billingType,
    {required Money hourlyRate,
    Money? bookingFee,
    String summary = 'Time and Materials Job'}) async {
  // Insert a job with time and materials billing type
  final job = Job.forInsert(
      customerId: 1, // Assuming a customer ID
      summary: summary,
      description: 'This is a T&M job',
      startDate: now,
      siteId: 1, // Assuming a site ID
      contactId: 1, // Assuming a contact ID
      jobStatusId: 1, // Assuming job status ID
      hourlyRate: hourlyRate, // $50 per hour
      bookingFee: bookingFee, // $100 Booking Fee
      billingType: billingType);
  await DaoJob().insert(job);

  return job;
}
