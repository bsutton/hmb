/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use by a single individual within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:math';

import 'package:calendar_view/calendar_view.dart';
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

// Example imports (replace with your actual ones):
import '../../dao/dao_job_activity.dart';
import '../../dao/dao_system.dart';
import '../../entity/operating_hours.dart';
import '../../entity/system.dart';
import '../../util/date_time_ex.dart';
import '../../util/format.dart';
import '../../util/local_date.dart';
import 'job_activity_ex.dart';
import 'schedule_helper.dart';

/// A single-week view of activities
class WeekSchedule extends StatefulWidget with ScheduleHelper {
  const WeekSchedule(
    this.initialDate, {
    required this.onPageChange,
    required this.defaultJob,
    required this.showExtendedHours,
    required this.weekKey,
    super.key,
  });

  final LocalDate initialDate;
  final int? defaultJob;
  final bool showExtendedHours;
  final Future<LocalDate> Function(LocalDate targetDate) onPageChange;
  final Key weekKey;

  @override
  State<WeekSchedule> createState() => _WeekScheduleState();
}

class _WeekScheduleState extends DeferredState<WeekSchedule> {
  late final EventController<JobActivityEx> _weekController;
  late final System system;
  late final bool showWeekends;
  late final OperatingHours operatingHours;
  late bool _hasActivitiesInExtendedHours;
  late LocalDate currentDate;

  @override
  void initState() {
    super.initState();
    currentDate = widget.initialDate;
    _weekController = EventController();
  }

  @override
  Future<void> asyncInitState() async {
    system = await DaoSystem().get();
    operatingHours = system.getOperatingHours();

    showWeekends = operatingHours.openOnWeekEnd();

    await _loadActivitiesForWeek();
  }

  @override
  void didUpdateWidget(covariant WeekSchedule oldWidget) {
    super.didUpdateWidget(oldWidget);
    currentDate = widget.initialDate;
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  Future<void> _loadActivitiesForWeek() async {
    final startOfWeek = _mondayOf(currentDate);
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final dao = DaoJobActivity();
    final jobActivities = await dao.getActivitiesInRange(
      startOfWeek,
      endOfWeek,
    );

    _hasActivitiesInExtendedHours = false;

    final eventData = <CalendarEventData<JobActivityEx>>[];
    for (final jobActivity in jobActivities) {
      var fontColor = Colors.white;
      if (widget.defaultJob == jobActivity.jobId) {
        fontColor = Colors.black;
      }
      _hasActivitiesInExtendedHours =
          _hasActivitiesInExtendedHours ||
          !operatingHours.inOperatingHours(jobActivity);

      final style = TextStyle(color: fontColor, fontSize: 13);
      eventData.add(
        (await JobActivityEx.fromActivity(
          jobActivity,
        )).eventData.copyWith(titleStyle: style, descriptionStyle: style),
      );
    }

    /// Occasionally when moving this can get called
    /// after we are demounted.
    if (mounted) {
      setState(() {
        _weekController
          ..clear()
          ..addAll(eventData);
      });
    }
  }

  /// Get the Monday date from [baseDate]
  LocalDate _mondayOf(LocalDate baseDate) {
    // In Dart, Monday=1, Sunday=7
    final dayOfWeek = baseDate.weekday;
    final difference =
        dayOfWeek - DateTime.monday; // how many days since Monday
    return LocalDate(baseDate.year, baseDate.month, baseDate.day - difference);
  }

  @override
  Widget build(BuildContext context) =>
      CalendarControllerProvider<JobActivityEx>(
        controller: _weekController,
        child: DeferredBuilder(
          this,
          builder: (context) => WeekView<JobActivityEx>(
            key: widget.weekKey,

            startHour: _getStartHour(),
            endHour: _getEndHour(),
            // key: ValueKey(currentDate),
            initialDay: currentDate.toDateTime(),
            headerStyle: widget.headerStyle(),
            timeLineWidth: 60,
            timeLineStringBuilder: (date, {secondaryDate}) =>
                formatTime(date, 'ha').toLowerCase(),
            weekTitleHeight: 60,
            showWeekends:
                widget.showExtendedHours ||
                showWeekends ||
                _hasActivitiesInExtendedHours,
            backgroundColor: Colors.black,
            headerStringBuilder: widget.dateStringBuilder,
            eventTileBuilder: _defaultEventTileBuilder,
            // ignore: discarded_futures
            onPageChange: (date, index) => _onPageChange(date),
            onDateTap: (date) async {
              await widget.addActivity(context, date, widget.defaultJob);
              await _loadActivitiesForWeek();
            },
            onEventTap: (events, date) async {
              await widget.onActivityTap(context, events.first);
              await _loadActivitiesForWeek();
            },
          ),
        ),
      );

  Future<void> _onPageChange(DateTime date) async {
    final revisedDate = await widget.onPageChange(date.toLocalDate());

    currentDate = revisedDate;
    await _loadActivitiesForWeek();
  }

  int _getEndHour() {
    if (widget.showExtendedHours || _hasActivitiesInExtendedHours) {
      return 24;
    }
    return min(24, _getLatestFinish(currentDate) + 1);
  }

  int _getStartHour() {
    if (widget.showExtendedHours || _hasActivitiesInExtendedHours) {
      return 0;
    }
    return max(0, _getEarliestStart(currentDate) - 1);
  }

  /// find the latest finishing hour across the week.
  int _getLatestFinish(LocalDate dayInWeek) {
    final operatingHours = system.getOperatingHours();
    final weekDays = _getDaysInCurrentWeek(dayInWeek);

    var latestHour = 0; // Initialize to the earliest possible hour.
    for (final day in weekDays) {
      final operatingDay = operatingHours.days[DayName.fromDate(day)];
      if (operatingDay!.open) {
        if (operatingDay.end != null) {
          final endHour = operatingDay.end!.hour;
          if (endHour > latestHour) {
            latestHour = endHour;
          }
        }
      }
    }
    return latestHour;
  }

  /// find the earliest starting hour across the week.
  int _getEarliestStart(LocalDate dayInWeek) {
    final operatingHours = system.getOperatingHours();
    final weekDays = _getDaysInCurrentWeek(dayInWeek);

    int? earliestHour; // Use null to find the first valid hour.
    for (final day in weekDays) {
      final operatingDay = operatingHours.days[DayName.fromDate(day)];
      if (operatingDay!.open) {
        if (operatingDay.start != null) {
          final startHour = operatingDay.start!.hour;
          if (earliestHour == null || startHour < earliestHour) {
            earliestHour = startHour;
          }
        }
      }
    }
    return earliestHour ?? 0; // Default to 0 if no valid start times exist.
  }

  /// Get the days of the current week.
  List<LocalDate> _getDaysInCurrentWeek(LocalDate referenceDate) {
    final startOfWeek = referenceDate.subtract(
      Duration(days: referenceDate.weekday - 1),
    );
    return List<LocalDate>.generate(
      7,
      (index) => startOfWeek.add(Duration(days: index)),
    );
  }

  Widget _defaultEventTileBuilder(
    DateTime date,
    List<CalendarEventData<JobActivityEx>> events,
    Rect boundary,
    DateTime startDuration,
    DateTime endDuration,
  ) => DefaultEventTile(
    date: date,
    events: events,
    boundary: boundary,
    startDuration: startDuration,
    endDuration: endDuration,
  );
}

/// This will be used in day and week view
class DefaultEventTile<T> extends StatelessWidget {
  const DefaultEventTile({
    required this.date,
    required this.events,
    required this.boundary,
    required this.startDuration,
    required this.endDuration,
    super.key,
  });

  final DateTime date;
  final List<CalendarEventData<T>> events;
  final Rect boundary;
  final DateTime startDuration;
  final DateTime endDuration;

  @override
  Widget build(BuildContext context) {
    if (events.isNotEmpty) {
      final event = events[0];
      return RoundedEventTile(
        borderRadius: BorderRadius.circular(10),
        title: event.title,
        totalEvents: events.length - 1,
        description: event.description,
        backgroundColor: event.color,
        margin: const EdgeInsets.all(2),
        titleStyle: event.titleStyle,
        descriptionStyle: event.descriptionStyle,
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
