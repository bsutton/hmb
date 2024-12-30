import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:intl/intl.dart';

import '../../dao/dao_customer.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../util/app_title.dart';
import '../../util/format.dart';
import '../widgets/layout/hmb_spacer.dart';
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

class _SchedulePageState extends State<SchedulePage> {
  View selectedView = View.month;

  List<JobEvent> jobEvents = [];

  late final EventController<JobEvent> eventController;

  @override
  void initState() {
    super.initState();
    setAppTitle('Schedule');
    eventController = EventController();
  }

  @override
  void dispose() {
    super.dispose();
    eventController.dispose();
  }

  @override
  Widget build(BuildContext context) => CalendarControllerProvider<JobEvent>(
        controller: eventController,
        child: Scaffold(
            appBar: AppBar(
                automaticallyImplyLeading: false,
                toolbarHeight: 90,
                actions: [
                  HMBDroplist<View>(
                      selectedItem: () async => selectedView,
                      items: (filter) async => View.values,
                      format: (view) => view.name,
                      onChanged: (view) => setState(() {
                            selectedView = view!;
                          }),
                      title: 'View')
                ]),
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: switch (selectedView) {
                View.month => _buildMonthView(context),
                View.week => _buildWeekView(),
                View.day => _buildDayView(),
              },
            )),
      );

  /// Day View
  DayView<JobEvent> _buildDayView() {
    late final DayView<JobEvent> dayView;

    // ignore: join_return_with_assignment
    dayView = DayView<JobEvent>(
      eventTileBuilder: (date, events, boundry, start, end) =>
          _dayTiles(dayView, events),
      fullDayEventBuilder: (events, date) =>
          const Text('full hi', style: TextStyle(color: Colors.white)),
      headerStyle: _headerStyle(),
      backgroundColor: Colors.black,
      onDateTap: (date) async {
        await _addEvent(context, date);
      },
    );

    return dayView;
  }

  /// Week View
  WeekView<JobEvent> _buildWeekView() => WeekView<JobEvent>(
        headerStyle: _headerStyle(),
        backgroundColor: Colors.black,
        headerStringBuilder: _dateStringBuilder,
        onDateTap: (date) async {
          await _addEvent(context, date);
        },
      );

  /// MonthView
  MonthView<JobEvent> _buildMonthView(BuildContext context) {
    late final MonthView<JobEvent> monthView;
    // ignore: join_return_with_assignment
    monthView = MonthView<JobEvent>(
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
      onEventTap: (event, date) async {
        final updatedEvent = await JobEventDialog.showEdit(context, event);
        if (updatedEvent != null) {
          eventController
            ..remove(event)
            ..add(updatedEvent.eventData);
          setState(() {});
        }
      },
    );

    return monthView;
  }

  Future<void> _addEvent(BuildContext context, DateTime date) async {
    final jobEvent = await JobEventDialog.showAdd(context: context, when: date);
    if (jobEvent != null) {
      setState(() {
        jobEvents.add(jobEvent);
        eventController.add(jobEvent.eventData);
      });
    }
  }

  /// Build even tile for the day view.
  Widget _dayTiles(DayView dayView, List<CalendarEventData<JobEvent>> events) {
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

  String _dateStringBuilder(DateTime date, {DateTime? secondaryDate}) {
    var formatted = DateFormat('yyyy/MM/dd').format(date);

    if (secondaryDate != null) {
      formatted = '$formatted ${DateFormat('yyyy/MM/dd').format(date)}';
    }

    return formatted;
  }

  Widget _cellBuilder(
    MonthView<JobEvent> monthView,
    DateTime date,
    List<CalendarEventData<JobEvent>> events,
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
      MonthView<JobEvent> monthView,
      DateTime date,
      bool isToday,
      List<CalendarEventData<JobEvent>> events,
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
    MonthView monthView,
    DateTime date,
    List<CalendarEventData<JobEvent>> events,
    bool isToday,
    bool isInMonth,
    bool hideDaysNotInMonth,
  ) {
    if (hideDaysNotInMonth) {
      return FilledCell<JobEvent>(
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
    return FilledCell<JobEvent>(
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

  Widget _renderEvent(MonthView<JobEvent> monthView,
          CalendarEventData<JobEvent> event, Color backgroundColour) =>
      GestureDetector(
        onTap: () async {
          if (monthView.onEventTap != null) {
            monthView.onEventTap!(event, event.startTime!);
          }
        },
        child: Text(
            '${formatTime(event.startTime!, 'h:mm a')} ${event.event!.job.summary}',
            style: TextStyle(
                color: Colors.white, backgroundColor: backgroundColour)),
      );
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

class JobEvent {
  JobEvent({
    required this.job,
    required this.start,
    required this.end,
  });
  Job job;
  DateTime start;
  DateTime end;

  CalendarEventData<JobEvent> get eventData => CalendarEventData(
      title: job.summary,
      description: job.description,
      date: start.withoutTime,
      startTime: start,
      endTime: end,
      event: this);
}
