import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';

import '../../dao/dao_job_activity.dart';
import '../../util/format.dart';
import '../../util/local_date.dart';
import 'job_activity_dialog.dart';
import 'job_activity_ex.dart';

typedef JobAddNotice = void Function(JobActivityEx jobActivityEx);
typedef JobUpdateNotice = void Function(
    JobActivityEx oldJob, JobActivityEx updatedJob);
typedef JobDeleteNotice = void Function(JobActivityEx jobActivityEx);

mixin ScheduleHelper {
  /// onEventTap
  Future<void> onActivityTap(
    BuildContext context,
    CalendarEventData<JobActivityEx> event,
  ) async {
    // Show the edit dialog for this activity
    final jobActivityAction =
        (await JobActivityDialog.showEdit(context, event))!;

    switch (jobActivityAction.action) {
      case EditAction.update:
        await _editExistingActivity(event, jobActivityAction.jobActivity!);
      case EditAction.delete:
        await _deleteActivity(event.event!);
      case EditAction.cancel:
    }
  }

  /// Add new Job activity
  Future<void> addActivity(
      BuildContext context, DateTime date, int? defaultJob) async {
    final jobActivityAction = (await JobActivityDialog.showAdd(
        context: context, defaultJob: defaultJob, when: date))!;

    final dao = DaoJobActivity();
    switch (jobActivityAction.action) {
      case AddAction.add:
        final newId =
            await dao.insert(jobActivityAction.jobActivity!.jobActivity);
        jobActivityAction.jobActivity!.jobActivity.id = newId;
      case AddAction.cancel:
    }
  }

  /// If the user updated an existing activity
  Future<void> _editExistingActivity(
      CalendarEventData<JobActivityEx> oldEvent, JobActivityEx updated) async {
    final dao = DaoJobActivity();

    // 1) Update DB
    await dao.update(updated.jobActivity);
  }

  /// Delete an existing activity from the DB
  Future<void> _deleteActivity(
    JobActivityEx activity,
  ) async {
    final dao = DaoJobActivity();
    await dao.delete(activity.jobActivity.id);
  }

  /// header style
  HeaderStyle headerStyle() => const HeaderStyle(
        leftIconConfig: IconDataConfig(color: Colors.white),
        rightIconConfig: IconDataConfig(color: Colors.white),
        headerTextStyle: TextStyle(
          color: Colors.white, // Set the text color for the header
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        decoration: BoxDecoration(
          color: Colors.black, // Set the background color for the header
          border: Border(
            bottom: BorderSide(
              color: Colors.white, // Colors.grey[800]!, // Add a bottom border
            ),
          ),
        ),
        headerMargin:
            EdgeInsets.symmetric(vertical: 8), // Optional: Adjust margin
        headerPadding:
            EdgeInsets.symmetric(horizontal: 16), // Optional: Adjust padding
      );

  /// Helper to format the date for headers
  String dateStringBuilder(DateTime date, {DateTime? secondaryDate}) {
    final today = LocalDate.today();
    String formatted;
    if (today.year == date.year) {
      /// If we are in the current year suppress the year.
      formatted = formatDate(date, format: 'M d');
    } else {
      formatted = formatDate(date, format: 'Y M d');
    }
    if (secondaryDate != null && secondaryDate.compareTo(date) != 0) {
      if (secondaryDate.month == date.month) {
        formatted = '$formatted - ${formatDate(secondaryDate, format: 'd')}';
      } else {
        formatted = '$formatted - ${formatDate(secondaryDate, format: 'M d')}';
      }
    }

    return formatted;
  }

  /// Helper to format the date for headers
  String monthDateStringBuilder(DateTime date, {DateTime? secondaryDate}) {
    final today = LocalDate.today();
    String formatted;
    if (today.year == date.year) {
      /// If we are in the current year suppress the year.
      formatted = formatDate(date, format: 'M');
    } else {
      formatted = formatDate(date, format: 'Y M');
    }

    return formatted;
  }
}
