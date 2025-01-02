import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';

import '../../dao/dao_job_event.dart';
// Example imports (replace with your actual ones):
import '../../util/format.dart'; // For formatTime() or similar
import '../widgets/surface.dart';
import '../widgets/text/hmb_text_themes.dart';
import 'job_event_ex.dart';
import 'schedule_helper.dart';

/// A single-month view of events
class MonthSchedule extends StatefulWidget with ScheduleHelper {
  const MonthSchedule(this.initialDate,
      {
        required this.defaultJob,
        required this.onAdd,
      required this.onUpdate,
      required this.onDelete,
      super.key});

  final DateTime initialDate;
  final int? defaultJob;

  final JobAddNotice onAdd;
  final JobUpdateNotice onUpdate;
  final JobDeleteNotice onDelete;

  @override
  State<MonthSchedule> createState() => _MonthScheduleState();
}

class _MonthScheduleState extends State<MonthSchedule> {
  late final EventController<JobEventEx> _monthController;

  @override
  void initState() {
    super.initState();
    _monthController = EventController();
    _loadEventsForMonth();
  }

  @override
  void dispose() {
    _monthController.dispose();
    super.dispose();
  }

  Future<void> _loadEventsForMonth() async {
    final firstOfMonth =
        DateTime(widget.initialDate.year, widget.initialDate.month);
    final firstOfNextMonth =
        DateTime(widget.initialDate.year, widget.initialDate.month + 1);

    final dao = DaoJobEvent();
    final jobEvents =
        await dao.getEventsInRange(firstOfMonth, firstOfNextMonth);

    final eventData = <CalendarEventData<JobEventEx>>[];
    for (final jobEvent in jobEvents) {
      eventData.add((await JobEventEx.fromEvent(jobEvent)).eventData);
    }

    setState(() {
      _monthController.removeAll(_monthController.allEvents);
      _monthController.addAll(eventData);
    });
  }

  @override
  Widget build(BuildContext context) {
    /// Month View

    late final MonthView<JobEventEx> monthView;
    // ignore: join_return_with_assignment
    monthView = MonthView<JobEventEx>(
      key: ValueKey(widget.initialDate),
      initialMonth: widget.initialDate,
      headerStyle: widget.headerStyle(),
      headerStringBuilder: widget.dateStringBuilder,
      cellBuilder: (date, events, isToday, isInMonth, hideDaysNotInMonth) =>
          _cellBuilder(monthView, date, events, isToday, isInMonth, hideDaysNotInMonth),
      weekDayBuilder: (day) => Center(
        child: Text(
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day],
          style: const TextStyle(color: Colors.white), // Weekday text color
        ),
      ),
      onCellTap: (events, date) async {
        await widget.addEvent(context, date, widget.defaultJob, widget.onAdd);
        await _loadEventsForMonth();
      },
      onEventTap: (event, date) async {
            await widget.onEventTap(
                context, event, widget.onUpdate, widget.onDelete);
            await _loadEventsForMonth();
          },
        );

    return CalendarControllerProvider<JobEventEx>(
        controller: _monthController,
        child: monthView,
      );
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
        ? Colors.yellow : (isInMonth ? Colors.white : Colors.black);

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
