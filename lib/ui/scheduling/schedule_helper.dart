import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';

import '../../dao/dao_job_event.dart';
import '../../util/format.dart';
import '../../util/local_date.dart';
import 'job_event_dialog.dart';
import 'job_event_ex.dart';

typedef JobAddNotice = void Function(JobEventEx jobEventEx);
typedef JobUpdateNotice = void Function(
    JobEventEx oldJob, JobEventEx updatedJob);
typedef JobDeleteNotice = void Function(JobEventEx jobEventEx);

mixin ScheduleHelper {
  /// onEventTap
  Future<void> onEventTap(
    BuildContext context,
    CalendarEventData<JobEventEx> event,
  ) async {
    // Show the edit dialog for this event
    final jobEventAction = (await JobEventDialog.showEdit(context, event))!;

    switch (jobEventAction.action) {
      case EditAction.update:
        await _editExistingEvent(event, jobEventAction.jobEvent!);
      case EditAction.delete:
        await _deleteEvent(event.event!);
      case EditAction.cancel:
    }
  }

  /// Add new Job Event
  Future<void> addEvent(
      BuildContext context, DateTime date, int? defaultJob) async {
    final jobEventAction = (await JobEventDialog.showAdd(
        context: context, defaultJob: defaultJob, when: date))!;

    final dao = DaoJobEvent();
    switch (jobEventAction.action) {
      case AddAction.add:
        final newId = await dao.insert(jobEventAction.jobEvent!.jobEvent);
        jobEventAction.jobEvent!.jobEvent.id = newId;
      case AddAction.cancel:
    }
  }

  /// If the user updated an existing event
  Future<void> _editExistingEvent(
      CalendarEventData<JobEventEx> oldEvent, JobEventEx updated) async {
    final dao = DaoJobEvent();

    // 1) Update DB
    await dao.update(updated.jobEvent);
  }

  /// Delete an existing event from the DB
  Future<void> _deleteEvent(
    JobEventEx event,
  ) async {
    final dao = DaoJobEvent();
    await dao.delete(event.jobEvent.id);
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
