import 'dart:math';

import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_job_activity.dart';
import '../../dao/dao_system.dart';
import '../../entity/operating_hours.dart';
import '../../entity/system.dart';
import '../../util/date_time_ex.dart';
import '../../util/format.dart';
import '../../util/local_date.dart';
import '../../util/local_time.dart';
import '../widgets/async_state.dart';
import '../widgets/circle.dart';
import '../widgets/layout/hmb_spacer.dart';
import '../widgets/surface.dart';
import '../widgets/text/hmb_text_themes.dart';
import 'job_activity_ex.dart';
import 'schedule_helper.dart';
import 'schedule_page.dart'; // so we have JobAddNotice, etc.

/// A single-day view of activity
class DaySchedule extends StatefulWidget with ScheduleHelper {
  DaySchedule(
    this.initialDate, {
    required this.defaultJob,
    required this.showExtendedHours,
    required this.onPageChange,
    required this.dayKey,
    super.key,
  });

  final LocalDate initialDate;
  final int? defaultJob;
  final bool showExtendedHours;
  final Future<LocalDate> Function(LocalDate targetDate) onPageChange;
  final Key dayKey;

  @override
  State<DaySchedule> createState() => _DayScheduleState();
}

class _DayScheduleState extends AsyncState<DaySchedule> {
  late final EventController<JobActivityEx> _dayController;
  late final System system;
  late final OperatingHours operatingHours;
  bool hasActivitiesInExtendedHours = false;
  late LocalDate currentDate;

  @override
  void initState() {
    super.initState();
    currentDate = widget.initialDate;
    _dayController = EventController();
  }

  @override
  Future<void> asyncInitState() async {
    system = await DaoSystem().get();
    operatingHours = system.getOperatingHours();
    await _loadActivitiesForDay();
  }

  @override
  void dispose() {
    _dayController.dispose();
    super.dispose();
  }

  /// Fetch activities for [currentDate] from DB
  Future<void> _loadActivitiesForDay() async {
    print('loadingDays');
    // Set a date range: midnight -> midnight next day
    final start = currentDate;
    final end = start.add(const Duration(days: 1));

    final dao = DaoJobActivity();
    final jobActivities = await dao.getActivitiesInRange(start, end);

    final activityData = <CalendarEventData<JobActivityEx>>[];
    var _hasActivitiesInExtendedHours = false;
    for (final jobActivity in jobActivities) {
      var fontColor = Colors.white;
      if (widget.defaultJob == jobActivity.jobId) {
        fontColor = Colors.orange;
      }

      _hasActivitiesInExtendedHours = _hasActivitiesInExtendedHours ||
          !operatingHours.inOperatingHours(jobActivity);

      activityData.add((await JobActivityEx.fromActivity(jobActivity))
          .eventData
          .copyWith(
              titleStyle: TextStyle(color: fontColor, fontSize: 13),
              descriptionStyle: TextStyle(color: fontColor, fontSize: 13),
              color: SurfaceElevation.e16.color));
    }
    hasActivitiesInExtendedHours = _hasActivitiesInExtendedHours;
    print('extened hours: $hasActivitiesInExtendedHours');

    if (mounted) {
      _dayController
        ..clear()
        ..addAll(activityData);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) =>
      CalendarControllerProvider<JobActivityEx>(
        controller: _dayController,
        child: FutureBuilderEx(
          future: initialised,
          builder: (context, _) {
            late final DayView<JobActivityEx> dayView;

            // ignore: join_return_with_assignment
            dayView = DayView<JobActivityEx>(
              onPageChange: (date, _) async => _onPageChange(date),
              startHour: _getStartHour(),
              endHour: _getEndHour(),
              key: widget.dayKey,
              initialDay: currentDate.toDateTime(),
              dateStringBuilder: dayTitle,
              timeStringBuilder: (date, {secondaryDate}) =>
                  formatTime(date, 'ha').toLowerCase(),
              heightPerMinute: 1.5,
              eventTileBuilder: (
                date,
                events,
                boundary,
                startDuration,
                endDuration,
              ) =>
                  _buildActvityCard(dayView, events.first),
              timeLineWidth: 58,
              fullDayEventBuilder: (events, date) => const Text(
                'Full Day Activity',
                style: TextStyle(color: Colors.white),
              ),
              headerStyle: widget.headerStyle(),
              backgroundColor: Colors.black,
              onDateTap: _onDateTap,
              onEventTap: _onEventTap,
            );
            return dayView;
          },
        ),
      );

  Future<void> _onPageChange(DateTime date) async {
    {
      currentDate = await widget.onPageChange(date.toLocalDate());

      /// force a refresh of the view so that the
      /// start/end hour range is re-evaluated for the
      /// current day.
      await _loadActivitiesForDay();
    }
  }

  Future<void> _onEventTap(
      List<CalendarEventData<JobActivityEx>> events, DateTime date) async {
    {
      // Only handle the first event in the list
      await widget.onActivityTap(context, events.first);
      // Refresh
      await _loadActivitiesForDay();
    }
  }

  Future<void> _onDateTap(DateTime date) async {
    {
      // Create new activity
      await widget.addActivity(context, date, widget.defaultJob);
      // Refresh
      await _loadActivitiesForDay();
    }
  }

  /// The opening hours starting time (hour only)
  int _getEndHour() {
    if (widget.showExtendedHours || hasActivitiesInExtendedHours) {
      return 24;
    }
    return min(
        24,
        (system.getOperatingHours().day(DayName.fromDate(currentDate)).end ??
                    const LocalTime(hour: 17, minute: 0))
                .hour +
            2);
  }

  /// The opening hours finishing time (hour only)
  int _getStartHour() {
    if (widget.showExtendedHours || hasActivitiesInExtendedHours) {
      return 0;
    }
    return max(
        0,
        (system.getOperatingHours().day(DayName.fromDate(currentDate)).start ??
                    const LocalTime(hour: 9, minute: 0))
                .hour -
            2);
  }

  /// A card for each activity, using a [FutureBuilderEx] to fetch job+customer
  Widget _buildActvityCard(
      DayView view, CalendarEventData<JobActivityEx> event) {
    final job = event.event?.job;
    if (job == null) {
      return const SizedBox();
    }

    final jobActivity = event.event;

    return FutureBuilderEx<JobAndCustomer>(
      // ignore: discarded_futures
      future: JobAndCustomer.fetch(job),
      builder: (context, jobAndCustomer) => SizedBox(
        height: view.heightPerMinute * (jobActivity?.durationInMinutes ?? 15),
        child: Card(
          color: SurfaceElevation.e6.color,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Align(
                alignment: Alignment.topLeft,
                child: Row(
                  children: [
                    if (jobActivity != null)
                      Circle(
                          color: jobActivity.jobActivity.status.color,
                          child: const Text('')),
                    const SizedBox(width: 5),
                    HMBTextLine(jobAndCustomer!.job.summary),
                    const HMBSpacer(width: true),
                    HMBTextLine(jobAndCustomer.customer.name),
                  ],
                )),
          ),
        ),
      ),
    );
  }

  String dayTitle(DateTime date, {DateTime? secondaryDate}) {
    final today = LocalDate.today();
    String formatted;
    if (today.year == date.year) {
      formatted = formatDate(date, format: 'M d D');
    } else {
      formatted = formatDate(date, format: 'Y M d D');
    }

    return formatted;
  }
}
