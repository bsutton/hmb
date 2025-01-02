import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';

import '../../util/format.dart';
import '../widgets/surface.dart';
import 'job_event_ex.dart';
import 'schedule_helper.dart';

class MonthSchedule extends StatelessWidget with ScheduleHelper {
  const MonthSchedule(this.initialDate,
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
    /// Month View

    late final MonthView<JobEventEx> monthView;
    // ignore: join_return_with_assignment
    monthView = MonthView<JobEventEx>(
      key: ValueKey(initialDate),
      initialMonth: initialDate,
      headerStyle: headerStyle(),
      headerStringBuilder: dateStringBuilder,
      cellBuilder: (date, events, isToday, isInMonth, hideDaysNotInMonth) =>
          _cellBuilder(
        monthView,
        date,
        events,
        isToday,
        isInMonth,
        hideDaysNotInMonth,
      ),
      weekDayBuilder: (day) => Center(
        child: Text(
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day],
          style: const TextStyle(color: Colors.white), // Weekday text color
        ),
      ),
      onCellTap: (events, date) async {
        await addEvent(context, date, onAdd);
      },
      onEventTap: (event, date) async =>
          onEventTap(context, event, onUpdate, onDelete),
    );

    return monthView;
  }

  /// Build month view cell.
  Widget _cellBuilder(
    MonthView<JobEventEx> monthView,
    DateTime date,
    List<CalendarEventData<JobEventEx>> events,
    bool isToday,
    bool isInMonth,
    bool hideDaysNotInMonth,
  ) {
    final backgroundColour = isToday
        ? SurfaceElevation.e4.color
        : isInMonth
            ? Colors.black
            : Colors.grey[350]!;

    final colour = isToday
        ? SurfaceElevation.e4.color
        : isInMonth
            ? Colors.white
            : Colors.black;

    return DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColour, // Cell background
          border: Border.all(color: Colors.grey[700]!), // Optional cell border
        ),
        child: Column(
            children: _renderEvents(
                monthView, date, isToday, events, backgroundColour,
                color: colour)));
  }

  /// Render a list of event widgets
  List<Widget> _renderEvents(
      MonthView<JobEventEx> monthView,
      DateTime date,
      bool isToday,
      List<CalendarEventData<JobEventEx>> events,
      Color backgroundColour,
      {required Color color}) {
    final widgets = <Widget>[];

    if (events.isEmpty) {
      widgets.add(Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: isToday ? Colors.yellow : color, // Text color
          ),
        ),
      ));
    } else {
      for (final event in events) {
        widgets.add(_renderEvent(monthView, event, backgroundColour));
      }
    }
    return widgets;
  }

  /// build a single event widget.
  Widget _renderEvent(MonthView<JobEventEx> monthView,
          CalendarEventData<JobEventEx> event, Color backgroundColour) =>
      GestureDetector(
        onTap: () async {
          if (monthView.onEventTap != null) {
            monthView.onEventTap?.call(event, event.startTime!);
          }
        },
        child: Text(
            '${formatTime(event.startTime!, 'h:mm a')} ${event.event!.job.summary}',
            style: TextStyle(
                color: Colors.white, backgroundColor: backgroundColour)),
      );
}
