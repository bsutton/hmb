import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';

// Example imports (replace with your actual ones):
import '../../dao/dao_job_event.dart';
import 'job_event_ex.dart';
import 'schedule_helper.dart';

/// A single-week view of events
class WeekSchedule extends StatefulWidget with ScheduleHelper {
  const WeekSchedule(
    this.initialDate, {
    required this.defaultJob,
    super.key,
  });

  final DateTime initialDate;
  final int? defaultJob;

  @override
  State<WeekSchedule> createState() => _WeekScheduleState();
}

class _WeekScheduleState extends State<WeekSchedule> {
  late final EventController<JobEventEx> _weekController;

  @override
  void initState() {
    super.initState();
    _weekController = EventController();
    _loadEventsForWeek();
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  Future<void> _loadEventsForWeek() async {
    final startOfWeek = _mondayOf(widget.initialDate);
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final dao = DaoJobEvent();
    final jobEvents = await dao.getEventsInRange(startOfWeek, endOfWeek);

    final eventData = <CalendarEventData<JobEventEx>>[];
    for (final jobEvent in jobEvents) {
      eventData.add((await JobEventEx.fromEvent(jobEvent)).eventData);
    }

    setState(() {
      _weekController
        ..removeAll(_weekController.allEvents)
        ..addAll(eventData);
    });
  }

  /// Example of getting the Monday date from [widget.initialDate]
  DateTime _mondayOf(DateTime d) {
    // In Dart, Monday=1, Sunday=7
    final dayOfWeek = d.weekday;
    final difference =
        dayOfWeek - DateTime.monday; // how many days since Monday
    return DateTime(d.year, d.month, d.day - difference);
  }

  @override
  Widget build(BuildContext context) => CalendarControllerProvider<JobEventEx>(
        controller: _weekController,
        child: WeekView<JobEventEx>(
          key: ValueKey(widget.initialDate),
          initialDay: widget.initialDate,
          headerStyle: widget.headerStyle(),
          backgroundColor: Colors.black,
          headerStringBuilder: widget.dateStringBuilder,
          onDateTap: (date) async {
            await widget.addEvent(context, date, widget.defaultJob);
            await _loadEventsForWeek();
          },
          onEventTap: (events, date) async {
            await widget.onEventTap(context, events.first);
            await _loadEventsForWeek();
          },
        ),
      );
}
