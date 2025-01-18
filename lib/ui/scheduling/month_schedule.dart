import 'package:calendar_view/calendar_view.dart';
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../dao/dao_job_activity.dart';
import '../../dao/dao_system.dart';
import '../../entity/operating_hours.dart';
import '../../entity/system.dart';
import '../../util/date_time_ex.dart';
import '../../util/format.dart'; // For formatTime() or similar
import '../../util/local_date.dart';
import '../widgets/circle.dart';
import '../widgets/surface.dart';
import 'job_activity_ex.dart';
import 'schedule_helper.dart';
import 'schedule_page.dart';

/// A single-month view of activities
class MonthSchedule extends StatefulWidget with ScheduleHelper {
  const MonthSchedule(
    this.initialDate, {
    required this.onPageChange,
    required this.defaultJob,
    required this.monthKey,
    required this.showWeekends,
    required this.schedulePageState,
    super.key,
  });

  final LocalDate initialDate;
  final int? defaultJob;
  final Future<LocalDate> Function(LocalDate targetDate) onPageChange;

  final GlobalKey<MonthViewState<JobActivityEx>> monthKey;
  final SchedulePageState schedulePageState;

  final bool showWeekends;

  @override
  State<MonthSchedule> createState() => _MonthScheduleState();
}

class _MonthScheduleState extends DeferredState<MonthSchedule> {
  late final EventController<JobActivityEx> _monthController;

  late LocalDate currentDate;
  late bool showWeekends;
  late final System system;
  late final OperatingHours operatingHours;

  @override
  void initState() {
    super.initState();
    showWeekends = widget.showWeekends;
    _monthController = EventController();
  }

  @override
  Future<void> asyncInitState() async {
    system = await DaoSystem().get();
    operatingHours = system.getOperatingHours();
    currentDate = widget.initialDate;
    await _loadActivitiesForMonth();
  }

  @override
  void dispose() {
    _monthController.dispose();
    super.dispose();
  }

  Future<void> _loadActivitiesForMonth() async {
    final firstOfMonth = LocalDate(currentDate.year, currentDate.month);
    final firstOfNextMonth = LocalDate(currentDate.year, currentDate.month + 1);

    final dao = DaoJobActivity();
    final jobActivites =
        await dao.getActivitiesInRange(firstOfMonth, firstOfNextMonth);

    showWeekends = false;
    final eventData = <CalendarEventData<JobActivityEx>>[];
    for (final jobActivity in jobActivites) {
      eventData.add((await JobActivityEx.fromActivity(jobActivity)).eventData);
      if (jobActivity.start.isWeekEnd) {
        showWeekends = true;
      }
    }

    setState(() {
      _monthController
        ..clear()
        ..addAll(eventData);
    });
  }

  @override
  Widget build(BuildContext context) =>
      CalendarControllerProvider<JobActivityEx>(
        controller: _monthController,
        child: DeferredBuilder(this, builder: (context) {
          /// Month View
          late final MonthView<JobActivityEx> monthView;
          // ignore: join_return_with_assignment
          monthView = MonthView<JobActivityEx>(
            showWeekends: showWeekends,
            // key: ValueKey(widget.initialDate),
            key: widget.monthKey,
            initialMonth: currentDate.toDateTime(),
            headerStyle: widget.headerStyle(),
            headerStringBuilder: widget.monthDateStringBuilder,
            onPageChange: (date, index) async => _onePageChange(date),
            cellBuilder:
                (date, events, isToday, isInMonth, hideDaysNotInMonth) =>
                    _cellBuilder(monthView, date, events, isToday, isInMonth,
                        hideDaysNotInMonth),
            weekDayBuilder: (day) => Center(
              child: Text(
                ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day],
                style:
                    const TextStyle(color: Colors.white), // Weekday text color
              ),
            ),
            onCellTap: (events, date) async {
              /// [date] is always midnight so lets show a more reasonable
              /// starting time for the event.
              final openingTime =
                  operatingHours.openingTime(date.toLocalDate());
              await widget.addActivity(
                  context, date.withTime(openingTime), widget.defaultJob);
              await _loadActivitiesForMonth();
            },
            onEventTap: (event, date) async {
              await widget.onActivityTap(context, event);
              await _loadActivitiesForMonth();
            },
          );
          return monthView;
        }),
      );

  Future<void> _onePageChange(DateTime date) async {
    final revisedDate = await widget.onPageChange(date.toLocalDate());

    currentDate = revisedDate;
    await _loadActivitiesForMonth();
  }

  /// Build month view cell.
  Widget _cellBuilder(
    MonthView<JobActivityEx> monthView,
    DateTime date,
    List<CalendarEventData<JobActivityEx>> events,
    bool isToday,
    bool isInMonth,
    bool hideDaysNotInMonth,
  ) {
    final backgroundColour = isToday
        ? SurfaceElevation.e4.color
        : isInMonth
            ? Colors.black
            : Colors.grey[350]!;

    final colour =
        isToday ? Colors.yellow : (isInMonth ? Colors.white : Colors.black);

    return DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColour, // Cell background
          border: Border.all(color: Colors.grey[700]!), // Optional cell border
        ),
        child: Column(
            children: _renderActivities(
                monthView, date, isToday, events, backgroundColour,
                color: colour)));
  }

  /// Render a list of event widgets
  List<Widget> _renderActivities(
      MonthView<JobActivityEx> monthView,
      DateTime date,
      bool isToday,
      List<CalendarEventData<JobActivityEx>> events,
      Color backgroundColour,
      {required Color color}) {
    final widgets = <Widget>[
      GestureDetector(
        onTap: () => widget.schedulePageState
            .showDateOnView(ScheduleView.week, date.toLocalDate()),
        child: Center(
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: isToday ? Colors.purpleAccent : color, // Text color
            ),
          ),
        ),
      )
    ];
    for (final event in events) {
      widgets.add(_renderActivity(monthView, event, backgroundColour));
    }
    return widgets;
  }

  /// build a single activity widget.
  Widget _renderActivity(MonthView<JobActivityEx> monthView,
      CalendarEventData<JobActivityEx> event, Color backgroundColour) {
    var fontColor = Colors.white;
    if (widget.defaultJob == event.event!.job.id) {
      fontColor = Colors.orange;
    }
    return GestureDetector(
      onTap: () async {
        if (monthView.onEventTap != null) {
          monthView.onEventTap?.call(event, event.startTime!);
        }
      },
      child: Row(
        children: [
          Circle(
              diameter: 15,
              color: event.event?.jobActivity.status.color ?? Colors.white,
              child: const Text('')),
          Text('${formatTime(event.startTime!, 'h:mm a').toLowerCase()} ',
              style: TextStyle(
                  color: fontColor, backgroundColor: backgroundColour)),
        ],
      ),
    );
  }
}
