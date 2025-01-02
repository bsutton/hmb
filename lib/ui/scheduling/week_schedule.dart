import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';

import 'job_event_ex.dart';
import 'schedule_helper.dart';

class WeekSchedule extends StatelessWidget with ScheduleHelper {
  const WeekSchedule(this.initialDate,
      {required this.onAdd,
      required this.onUpdate,
      required this.onDelete,
      super.key});

  final DateTime initialDate;

  final JobAddNotice onAdd;
  final JobUpdateNotice onUpdate;
  final JobDeleteNotice onDelete;

  @override
  Widget build(BuildContext context) => WeekView<JobEventEx>(
        key: ValueKey(initialDate),
        initialDay: initialDate,
        headerStyle: headerStyle(),
        backgroundColor: Colors.black,
        headerStringBuilder: dateStringBuilder,
        onDateTap: (date) async {
          await addEvent(context, date, onAdd);
        },
        onEventTap: (events, date) async =>
            onEventTap(context, events.first, onUpdate, onDelete),
      );
}
