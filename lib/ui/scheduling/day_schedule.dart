import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../widgets/layout/hmb_spacer.dart';
import '../widgets/text/hmb_text_themes.dart';
import 'job_event_ex.dart';
import 'schedule_helper.dart';
import 'schedule_page.dart';

class DaySchedule extends StatelessWidget with ScheduleHelper {
  const DaySchedule(this.initialDate,
      {required this.onAdd,
      required this.onUpdate,
      required this.onDelete,
      super.key});

  final DateTime initialDate;

  final JobAddNotice onAdd;
  final JobUpdateNotice onUpdate;
  final JobDeleteNotice onDelete;

  @override
  Widget build(BuildContext context) {
    /// Day View
    late final DayView<JobEventEx> dayView;

    // ignore: join_return_with_assignment
    dayView = DayView<JobEventEx>(
      key: ValueKey(initialDate),
      initialDay: initialDate,
      eventTileBuilder: (date, events, boundry, start, end) =>
          _dayTiles(dayView, events),
      fullDayEventBuilder: (events, date) =>
          const Text('Full Day Event', style: TextStyle(color: Colors.white)),
      headerStyle: headerStyle(),
      backgroundColor: Colors.black,
      onDateTap: (date) async {
        await addEvent(context, date, onAdd);
      },
      onEventTap: (events, date) async =>
          onEventTap(context, events.first, onUpdate, onDelete),
    );

    return dayView;
  }

  /// Build each day tile
  Widget _dayTiles(
      DayView dayView, List<CalendarEventData<JobEventEx>> events) {
    final tiles = <Widget>[];
    for (final event in events) {
      final job = event.event!.job;

      final height = dayView.heightPerMinute * event.duration.inMinutes;

      final builder = FutureBuilderEx<JobAndCustomer>(
          // ignore: discarded_futures
          future: JobAndCustomer.fetch(job),
          builder: (context, jobAndCustomer) => SizedBox(
                height: height,
                child: Card(
                  color: Colors.blue,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(children: [
                      HMBTextLine(jobAndCustomer!.job.summary),
                      const HMBSpacer(width: true),
                      HMBTextLine(jobAndCustomer.customer.name)
                    ]),
                  ),
                ),
              ));
      tiles.add(builder);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tiles,
    );
  }
}
