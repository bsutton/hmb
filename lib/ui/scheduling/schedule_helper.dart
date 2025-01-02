import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';

import '../../dao/dao_job_event.dart';
import '../../util/format.dart';
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
    
    JobUpdateNotice onUpdate,
    JobDeleteNotice onDelete,
  ) async {
    // Show the edit dialog for this event
    final jobEventAction = (await JobEventDialog.showEdit(context, event))!;

    switch (jobEventAction.action) {
      case EditAction.update:
        await _editExistingEvent(event, jobEventAction.jobEvent!, onUpdate);
      case EditAction.delete:
        await _deleteEvent(event.event!, onDelete);
      case EditAction.cancel:
    }
  }

  /// Add new Job Event
  Future<void> addEvent(
      BuildContext context, DateTime date, 
      int? defaultJob,
      JobAddNotice onDone) async {
    final jobEventAction =
        (await JobEventDialog.showAdd(context: context, defaultJob: defaultJob, when: date))!;

    final dao = DaoJobEvent();
    switch (jobEventAction.action) {
      case AddAction.add:
        final newId = await dao.insert(jobEventAction.jobEvent!.jobEvent);
        jobEventAction.jobEvent!.jobEvent.id = newId;
        onDone(jobEventAction.jobEvent!);
      case AddAction.cancel:
    }
  }

  /// If the user updated an existing event
  Future<void> _editExistingEvent(CalendarEventData<JobEventEx> oldEvent,
      JobEventEx updated, JobUpdateNotice onDone) async {
    final dao = DaoJobEvent();

    // 1) Update DB
    await dao.update(updated.jobEvent);

    onDone(oldEvent.event!, updated);
  }

  /// Delete an existing event from the DB
  Future<void> _deleteEvent(JobEventEx event, JobDeleteNotice onDone) async {
    final dao = DaoJobEvent();
    await dao.delete(event.jobEvent.id);

    onDone(event);
  }

  /// header style
  HeaderStyle headerStyle() => const HeaderStyle(
        headerTextStyle: TextStyle(
          color: Colors.white, // Set the text color for the header
          fontSize: 20,
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
    var formatted = formatDate(date, format: 'Y M d');

    if (secondaryDate != null && secondaryDate.compareTo(date) != 0) {
      formatted = '$formatted - ${formatDate(secondaryDate, format: 'y M d')}';
    }

    return formatted;
  }
}
