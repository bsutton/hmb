import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

// Example imports (replace with your actual ones):
import '../../dao/dao_job_event.dart';
import '../widgets/layout/hmb_spacer.dart';
import '../widgets/text/hmb_text_themes.dart';
import 'job_event_ex.dart';
import 'schedule_helper.dart';
import 'schedule_page.dart'; // so we have JobAddNotice, etc.

/// A single-day view of events
class DaySchedule extends StatefulWidget with ScheduleHelper {
  const DaySchedule(
    this.initialDate, {
    required this.defaultJob,
    super.key,
  });

  final DateTime initialDate;
  final int? defaultJob;

  @override
  State<DaySchedule> createState() => _DayScheduleState();
}

class _DayScheduleState extends State<DaySchedule> {
  late final EventController<JobEventEx> _dayController;

  @override
  void initState() {
    super.initState();
    _dayController = EventController();
    _loadEventsForDay();
  }

  @override
  void dispose() {
    _dayController.dispose();
    super.dispose();
  }

  /// Fetch events for [widget.initialDate] from DB
  Future<void> _loadEventsForDay() async {
    // Set a date range: midnight -> midnight next day
    final start = DateTime(widget.initialDate.year, widget.initialDate.month,
        widget.initialDate.day);
    final end = start.add(const Duration(days: 1));

    final dao = DaoJobEvent();
    // Implement getEventsInRange in your DaoJobEvent:
    final jobEvents = await dao.getEventsInRange(start, end);

    final eventData = <CalendarEventData<JobEventEx>>[];
    for (final jobEvent in jobEvents) {
      eventData.add((await JobEventEx.fromEvent(jobEvent)).eventData);
    }

    setState(() {
      _dayController
        ..removeAll(_dayController.allEvents)
        ..addAll(eventData);
    });
  }

  @override
  Widget build(BuildContext context) => CalendarControllerProvider<JobEventEx>(
        controller: _dayController,
        child: DayView<JobEventEx>(
          key: ValueKey(widget.initialDate),
          initialDay: widget.initialDate,
          dateStringBuilder: widget.dateStringBuilder,
          eventTileBuilder: (date, events, boundary, start, end) =>
              _buildDayTiles(events),
          fullDayEventBuilder: (events, date) => const Text(
            'Full Day Event',
            style: TextStyle(color: Colors.white),
          ),
          headerStyle: widget.headerStyle(),
          backgroundColor: Colors.black,
          onDateTap: (date) async {
            // Create new event
            await widget.addEvent(context, date, widget.defaultJob);
            // Refresh
            await _loadEventsForDay();
          },
          onEventTap: (events, date) async {
            // Only handle the first event in the list
            await widget.onEventTap(context, events.first);
            // Refresh
            await _loadEventsForDay();
          },
        ),
      );

  /// Build the event widgets for each timeslot in the day
  Widget _buildDayTiles(List<CalendarEventData<JobEventEx>> events) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final event in events) _buildEventCard(event),
        ],
      );

  /// A card for each event, using a [FutureBuilderEx] to fetch job+customer
  Widget _buildEventCard(CalendarEventData<JobEventEx> event) {
    final job = event.event?.job;
    if (job == null) {
      return const SizedBox();
    }

    return FutureBuilderEx<JobAndCustomer>(
      // ignore: discarded_futures
      future: JobAndCustomer.fetch(job),
      builder: (context, jobAndCustomer) => Card(
        color: Colors.blue,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              HMBTextLine(jobAndCustomer!.job.summary),
              const HMBSpacer(width: true),
              HMBTextLine(jobAndCustomer.customer.name),
            ],
          ),
        ),
      ),
    );
  }
}
