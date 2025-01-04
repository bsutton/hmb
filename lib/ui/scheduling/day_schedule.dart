import 'dart:math';

import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

// Example imports (replace with your actual ones):
import '../../dao/dao_job_event.dart';
import '../../dao/dao_system.dart';
import '../../entity/system.dart';
import '../../util/format.dart';
import '../../util/local_date.dart';
import '../../util/local_time.dart';
import '../widgets/async_state.dart';
import '../widgets/layout/hmb_spacer.dart';
import '../widgets/surface.dart';
import '../widgets/text/hmb_text_themes.dart';
import 'job_event_ex.dart';
import 'schedule_helper.dart';
import 'schedule_page.dart'; // so we have JobAddNotice, etc.

/// A single-day view of events
class DaySchedule extends StatefulWidget with ScheduleHelper {
  DaySchedule(
    this.initialDate, {
    required this.defaultJob,
    required this.showExtendedHours,
    super.key,
  });

  final LocalDate initialDate;
  final int? defaultJob;
  final bool showExtendedHours;

  @override
  State<DaySchedule> createState() => _DayScheduleState();
}

class _DayScheduleState extends AsyncState<DaySchedule, void> {
  late final EventController<JobEventEx> _dayController;
  late final System system;
  late final OperatingHours operatingHours;
  bool hasEventsInExtendedHours = false;

  @override
  void initState() {
    super.initState();
    _dayController = EventController();
  }

  @override
  Future<void> asyncInitState() async {
    system = (await DaoSystem().get())!;
    operatingHours = system.getOperatingHours();
    await _loadEventsForDay();
  }

  @override
  void didUpdateWidget(DaySchedule old) {
    super.didUpdateWidget(old);
  }

  @override
  void dispose() {
    _dayController.dispose();
    super.dispose();
  }

  /// Fetch events for [DaySchedule.initialDate] from DB
  Future<void> _loadEventsForDay() async {
    // Set a date range: midnight -> midnight next day
    final start = LocalDate(widget.initialDate.year, widget.initialDate.month,
        widget.initialDate.day);
    final end = start.add(const Duration(days: 1));

    final dao = DaoJobEvent();
    // Implement getEventsInRange in your DaoJobEvent:
    final jobEvents = await dao.getEventsInRange(start, end);

    final eventData = <CalendarEventData<JobEventEx>>[];
    var _hasEventsInExtendedHours = false;
    for (final jobEvent in jobEvents) {
      var fontColor = Colors.white;
      if (widget.defaultJob == jobEvent.jobId) {
        fontColor = Colors.orange;
      }

      _hasEventsInExtendedHours = _hasEventsInExtendedHours ||
          !operatingHours.inOperatingHours(jobEvent);

      eventData.add((await JobEventEx.fromEvent(jobEvent)).eventData.copyWith(
          titleStyle: TextStyle(color: fontColor, fontSize: 13),
          descriptionStyle: TextStyle(color: fontColor, fontSize: 13),
          color: SurfaceElevation.e16.color));
    }
    hasEventsInExtendedHours = _hasEventsInExtendedHours;

    _dayController
      ..clear()
      ..addAll(eventData);
  }

  @override
  Widget build(BuildContext context) => CalendarControllerProvider<JobEventEx>(
        controller: _dayController,
        child: FutureBuilderEx(
          future: initialised,
          builder: (context, _) => DayView<JobEventEx>(
            startHour: _getStartHour(),
            endHour: _getEndHour(),
            key: ValueKey(widget.initialDate),
            initialDay: widget.initialDate.toDateTime(),
            dateStringBuilder: dayTitle,
            // eventTileBuilder: (date, events, boundary, start, end) =>
            //     _buildDayTiles(events),
            fullDayEventBuilder: (events, date) => const Text(
              'Full Day Event',
              style: TextStyle(color: Colors.white),
            ),
            headerStyle: widget.headerStyle(),
            backgroundColor: Colors.black,
            onDateTap: _onDateTap,
            onEventTap: _onEventTap,
          ),
        ),
      );

  Future<void> _onEventTap(
      List<CalendarEventData<JobEventEx>> events, DateTime date) async {
    {
      // Only handle the first event in the list
      await widget.onEventTap(context, events.first);
      // Refresh
      await _loadEventsForDay();
    }
  }

  Future<void> _onDateTap(DateTime date) async {
    {
      // Create new event
      await widget.addEvent(context, date, widget.defaultJob);
      // Refresh
      await _loadEventsForDay();
    }
  }

  /// The opening hours starting time (hour only)
  int _getEndHour() {
    if (widget.showExtendedHours || hasEventsInExtendedHours) {
      return 24;
    }
    return min(
        24,
        (system
                        .getOperatingHours()
                        .day(DayName.fromDate(widget.initialDate))
                        .end ??
                    const LocalTime(hour: 17, minute: 0))
                .hour +
            2);
  }

  /// The opening hours finishing time (hour only)
  int _getStartHour() {
    if (widget.showExtendedHours || hasEventsInExtendedHours) {
      return 0;
    }
    return max(
        0,
        (system
                        .getOperatingHours()
                        .day(DayName.fromDate(widget.initialDate))
                        .start ??
                    const LocalTime(hour: 9, minute: 0))
                .hour -
            2);
  }

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

  String dayTitle(DateTime date, {DateTime? secondaryDate}) {
    final formatted = formatDate(date, format: 'Y M d D');

    return formatted;
  }
}
