// schedule_page.dart
import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:intl/intl.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_job_event.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../entity/job_event.dart';
import '../../util/app_title.dart';
import '../../util/format.dart';
import '../widgets/async_state.dart';
import '../widgets/layout/hmb_spacer.dart';
import '../widgets/media/rich_editor.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/surface.dart';
import '../widgets/text/hmb_text_themes.dart';
import 'job_event_dialog.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

enum View { month, week, day }

class JobEventEx {
  JobEventEx._(this.job, this.jobEvent);

  static Future<JobEventEx> fromEvent(JobEvent jobEvent) async {
    final job = await DaoJob().getById(jobEvent.jobId);

    return JobEventEx._(job!, jobEvent);
  }

  final JobEvent jobEvent;
  late final Job job;

  CalendarEventData<JobEventEx> get eventData => CalendarEventData(
        title: job.summary,
        description: RichEditor.createParchment(job.description)
            .toPlainText()
            .replaceAll('\n\n', '\n'),
        date: jobEvent.startDate.withoutTime,
        startTime: jobEvent.startDate,
        endTime: jobEvent.endDate,
        event: this,
      );
}

class _SchedulePageState extends AsyncState<SchedulePage, void> {
  View selectedView = View.month;
  late final EventController<JobEventEx> eventController;

  final PageController _pageController = PageController();
  DateTime currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    setAppTitle('Schedule');
    eventController = EventController();
  }

  @override
  Future<void> asyncInitState() async {
    await _loadEventsFromDb();
  }

  @override
  void dispose() {
    eventController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadEventsFromDb() async {
    final dao = DaoJobEvent();
    final jobEvents = await dao.getAll();

    final eventData = <CalendarEventData<JobEventEx>>[];
    for (final jobEvent in jobEvents) {
      eventData.add((await JobEventEx.fromEvent(jobEvent)).eventData);
    }

    eventController
      ..removeAll(eventController.allEvents)
      ..addAll(eventData);
  }

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
        future: initialised,
        builder: (context, _) => CalendarControllerProvider<JobEventEx>(
          controller: eventController,
          child: Scaffold(
            body: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: HMBDroplist<View>(
                        selectedItem: () async => selectedView,
                        items: (filter) async => View.values,
                        format: (view) => view.name,
                        onChanged: (view) => setState(() {
                          selectedView = view!;
                        }),
                        title: 'View',
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        currentDate = _getDateForPage(index);
                      });
                    },
                    itemBuilder: (context, index) {
                      final date = _getDateForPage(index);
                      return switch (selectedView) {
                        View.month => _buildMonthView(context, date),
                        View.week => _buildWeekView(date),
                        View.day => _buildDayView(date),
                      };
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  /// Calculates the date for the given page index.
  DateTime _getDateForPage(int pageIndex) {
    final today = DateTime.now();
    return switch (selectedView) {
      View.month => DateTime(today.year, today.month + pageIndex),
      View.week => today.add(Duration(days: 7 * pageIndex)),
      View.day => today.add(Duration(days: pageIndex)),
    };
  }

  /// Day View
  DayView<JobEventEx> _buildDayView(DateTime date) {
    late final DayView<JobEventEx> dayView;

    // ignore: join_return_with_assignment
    dayView = DayView<JobEventEx>(
      key: ValueKey(date),
      initialDay: date,
      eventTileBuilder: (date, events, boundry, start, end) =>
          _dayTiles(dayView, events),
      fullDayEventBuilder: (events, date) =>
          const Text('Full Day Event', style: TextStyle(color: Colors.white)),
      headerStyle: _headerStyle(),
      backgroundColor: Colors.black,
      onDateTap: (date) async {
        await _addEvent(context, date);
      },
      onEventTap: (events, date) async => _onEventTap(context, events.first),
    );

    return dayView;
  }

  /// Week View
  WeekView<JobEventEx> _buildWeekView(DateTime date) => WeekView<JobEventEx>(
        key: ValueKey(date),
        initialDay: date,
        headerStyle: _headerStyle(),
        backgroundColor: Colors.black,
        headerStringBuilder: _dateStringBuilder,
        onDateTap: (date) async {
          await _addEvent(context, date);
        },
        onEventTap: (events, date) async => _onEventTap(context, events.first),
      );

  /// Month View
  MonthView<JobEventEx> _buildMonthView(BuildContext context, DateTime date) {
    late final MonthView<JobEventEx> monthView;
    // ignore: join_return_with_assignment
    monthView = MonthView<JobEventEx>(
      key: ValueKey(date),
      initialMonth: date,
      headerStyle: _headerStyle(),
      headerStringBuilder: _dateStringBuilder,
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
        await _addEvent(context, date);
      },
      onEventTap: (event, date) async => _onEventTap(context, event),
    );

    return monthView;
  }

  /// onEventTap
  Future<void> _onEventTap(
      BuildContext context, CalendarEventData<JobEventEx> event) async {
    {
      // Show the edit dialog for this event
      final updatedEvent = await JobEventDialog.showEdit(context, event);
      if (updatedEvent == null) {
        // Delete requested
        if (event.event != null) {
          await _deleteEvent(event.event!);
        }
      } else {
        // Update requested
        await _editExistingEvent(event, updatedEvent);
      }
    }
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

  /// header style
  HeaderStyle _headerStyle() => const HeaderStyle(
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
  String _dateStringBuilder(DateTime date, {DateTime? secondaryDate}) {
    var formatted = DateFormat('yyyy MMM dd').format(date);

    if (secondaryDate != null && secondaryDate.compareTo(date) != 0) {
      formatted =
          '$formatted - ${DateFormat('yy MMM dd').format(secondaryDate)}';
    }

    return formatted;
  }

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
            : SurfaceElevation.e24.color;

    return DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColour, // Cell background
          border: Border.all(color: Colors.grey[700]!), // Optional cell border
        ),
        child: Column(
            children: _renderEvents(
                monthView, date, isToday, events, backgroundColour)));
  }

  /// Render a list of event widgets
  List<Widget> _renderEvents(
      MonthView<JobEventEx> monthView,
      DateTime date,
      bool isToday,
      List<CalendarEventData<JobEventEx>> events,
      Color backgroundColour) {
    final widgets = <Widget>[];

    if (events.isEmpty) {
      widgets.add(Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: isToday ? Colors.yellow : Colors.white, // Text color
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

  Widget _defaultCellBuilder(
    MonthView<JobEventEx> monthView,
    DateTime date,
    List<CalendarEventData<JobEventEx>> events,
    bool isToday,
    bool isInMonth,
    bool hideDaysNotInMonth,
  ) {
    if (hideDaysNotInMonth) {
      return FilledCell<JobEventEx>(
        date: date,
        shouldHighlight: isToday,
        backgroundColor: isInMonth ? Colors.black : Colors.white60,
        events: events,
        isInMonth: isInMonth,
        onTileTap: monthView.onEventTap,
        onTileLongTap: monthView.onEventLongTap,
        onTileDoubleTap: monthView.onEventDoubleTap,
        dateStringBuilder: _dateStringBuilder,
        hideDaysNotInMonth: hideDaysNotInMonth,
      );
    }
    return FilledCell<JobEventEx>(
      date: date,
      shouldHighlight: isToday,
      backgroundColor: isInMonth ? Colors.black : Colors.white60,
      events: events,
      onTileTap: monthView.onEventTap,
      onTileLongTap: monthView.onEventLongTap,
      onTileDoubleTap: monthView.onEventDoubleTap,
      dateStringBuilder: _dateStringBuilder,
      hideDaysNotInMonth: hideDaysNotInMonth,
    );
  }

  /// build a single event widget.
  // Widget _renderEvent(
  //         List<Widget> widgets, CalendarEventData<JobEvent> event) =>
  //     SurfaceCard(title: event.event!.job.summary, body: const Text(''));

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

  Future<void> _addEvent(BuildContext context, DateTime date) async {
    final jobEventEx =
        await JobEventDialog.showAdd(context: context, when: date);
    if (jobEventEx != null) {
      // Insert to DB
      final dao = DaoJobEvent();
      final newId = await dao.insert(jobEventEx.jobEvent);
      jobEventEx.jobEvent.id = newId;

      // Add to our in-memory list & calendar
      setState(() {
        eventController.add(jobEventEx.eventData);
      });
    }
  }

  /// If the user updated an existing event
  Future<void> _editExistingEvent(
    CalendarEventData<JobEventEx> oldEvent,
    JobEventEx updated,
  ) async {
    final dao = DaoJobEvent();

    // 1) Update DB
    await dao.update(updated.jobEvent);

    // 2) Remove old from the calendar, re-add updated
    eventController
      ..remove(oldEvent)
      ..add(updated.eventData);

    setState(() {});
  }

  /// Delete an existing event from the DB
  Future<void> _deleteEvent(JobEventEx event) async {
    final dao = DaoJobEvent();
    await dao.delete(event.jobEvent.id);

    setState(() {
      // Remove from local memory & calendar
      eventController.remove(event.eventData);
    });
  }
}

class JobAndCustomer {
  JobAndCustomer(this.job, this.customer);

  static Future<JobAndCustomer> fetch(Job job) async {
    final customer = await DaoCustomer().getByJob(job.id);

    return JobAndCustomer(job, customer!);
  }

  Job job;
  Customer customer;
}
