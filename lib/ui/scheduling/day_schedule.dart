import 'dart:math';

import 'package:calendar_view/calendar_view.dart';
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao.g.dart';
import '../../entity/operating_hours.dart';
import '../../entity/system.dart';
import '../../util/date_time_ex.dart';
import '../../util/format.dart';
import '../../util/local_date.dart';
import '../dialog/dialog.g.dart';
import '../widgets/circle.dart';
import '../widgets/hmb_mail_to_icon.dart';
import '../widgets/hmb_map_icon.dart';
import '../widgets/hmb_phone_icon.dart';
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

class _DayScheduleState extends DeferredState<DaySchedule> {
  late final EventController<JobActivityEx> _dayController;
  late final System system;
  late final OperatingHours operatingHours;
  bool hasActivitiesInExtendedHours = false;
  // New state variables to hold the computed bounds when there are extended activities.
  int? _computedStartHour;
  int? _computedEndHour;
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

  /// Fetch activities for [currentDate] from DB and compute extended hour bounds if needed.
  Future<void> _loadActivitiesForDay() async {
    print('loadingDays');
    // Set a date range: midnight -> midnight next day
    final start = currentDate;
    final end = start.add(const Duration(days: 1));

    final dao = DaoJobActivity();
    final jobActivities = await dao.getActivitiesInRange(start, end);

    final activityData = <CalendarEventData<JobActivityEx>>[];

    // Variables to track extended event bounds.
    var foundExtended = false;
    var earliestExtendedHour = 24;
    var latestExtendedHour = 0;
    const buffer = 1; // 1 hour buffer for both operating and extended times

    for (final jobActivity in jobActivities) {
      var fontColor = Colors.white;
      if (widget.defaultJob == jobActivity.jobId) {
        fontColor = Colors.orange;
      }

      // Check if this activity is outside operating hours.
      if (!operatingHours.inOperatingHours(jobActivity)) {
        foundExtended = true;
        // Assuming jobActivity has a 'startTime' property and a 'durationInMinutes' property.
        final eventStart = jobActivity.start;
        final eventEnd = jobActivity.end;
        final eventStartHour = eventStart.hour;
        // Round up the end hour if there are remaining minutes.
        var eventEndHour = eventEnd.hour;
        if (eventEnd.minute > 0) {
          eventEndHour++;
        }
        earliestExtendedHour = min(earliestExtendedHour, eventStartHour);
        latestExtendedHour = max(latestExtendedHour, eventEndHour);
      }

      activityData.add(
        (await JobActivityEx.fromActivity(jobActivity)).eventData.copyWith(
          titleStyle: TextStyle(color: fontColor, fontSize: 13),
          descriptionStyle: TextStyle(color: fontColor, fontSize: 13),
          color: SurfaceElevation.e16.color,
        ),
      );
    }

    // Get operating hours for the current day.
    final dayOperating = system.getOperatingHours().day(
      DayName.fromDate(currentDate),
    );
    final operatingStartHour = dayOperating.start?.hour ?? 9;
    final operatingEndHour = dayOperating.end?.hour ?? 17;
    // Default buffered operating hours with a 1-hour buffer.
    final int defaultStart = max(0, operatingStartHour - buffer);
    final int defaultEnd = min(24, operatingEndHour + buffer);

    if (foundExtended) {
      hasActivitiesInExtendedHours = true;
      // Apply a 1-hour buffer to extended event bounds.
      _computedStartHour = min(
        defaultStart,
        max(0, earliestExtendedHour - buffer),
      );
      _computedEndHour = max(defaultEnd, min(24, latestExtendedHour + buffer));
    } else {
      hasActivitiesInExtendedHours = false;
      _computedStartHour = null;
      _computedEndHour = null;
    }

    print('Extended hours: $hasActivitiesInExtendedHours');
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
        child: DeferredBuilder(
          this,
          builder: (context) {
            late final DayView<JobActivityEx> dayView;

            // ignore: join_return_with_assignment
            dayView = DayView<JobActivityEx>(
              onPageChange: (date, _) async => _onPageChange(date),
              startHour: _getStartHour(),
              endHour: _getEndHour(),
              key: widget.dayKey,
              initialDay: currentDate.toDateTime(),
              dateStringBuilder: dayTitle,
              timeStringBuilder:
                  (date, {secondaryDate}) =>
                      formatTime(date, 'ha').toLowerCase(),
              heightPerMinute: 1.5,
              eventTileBuilder:
                  (date, events, boundary, startDuration, endDuration) =>
                      _buildActvityCard(dayView, events.first),
              timeLineWidth: 58,
              fullDayEventBuilder:
                  (events, date) => const Text(
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
    currentDate = await widget.onPageChange(date.toLocalDate());

    /// Force a refresh of the view so that the start/end hour range is re-evaluated for the current day.
    await _loadActivitiesForDay();
  }

  Future<void> _onEventTap(
    List<CalendarEventData<JobActivityEx>> events,
    DateTime date,
  ) async {
    // Only handle the first event in the list.
    await widget.onActivityTap(context, events.first);
    // Refresh.
    await _loadActivitiesForDay();
  }

  Future<void> _onDateTap(DateTime date) async {
    // Create new activity.
    await widget.addActivity(context, date, widget.defaultJob);
    // Refresh.
    await _loadActivitiesForDay();
  }

  /// Determine the start hour for the day view.
  int _getStartHour() {
    final dayOperating = system.getOperatingHours().day(
      DayName.fromDate(currentDate),
    );
    final operatingStartHour = dayOperating.start?.hour ?? 9;
    const buffer = 1;
    if (hasActivitiesInExtendedHours && _computedStartHour != null) {
      return _computedStartHour!;
    }
    return max(0, operatingStartHour - buffer);
  }

  /// Determine the end hour for the day view.
  int _getEndHour() {
    final dayOperating = system.getOperatingHours().day(
      DayName.fromDate(currentDate),
    );
    final operatingEndHour = dayOperating.end?.hour ?? 17;
    const buffer = 1;
    if (hasActivitiesInExtendedHours && _computedEndHour != null) {
      return _computedEndHour!;
    }
    return min(24, operatingEndHour + buffer);
  }

  /// A card for each activity, using a [FutureBuilderEx] to fetch job+customer.
  Widget _buildActvityCard(
    DayView view,
    CalendarEventData<JobActivityEx> event,
  ) {
    final job = event.event?.job;
    if (job == null) {
      return const SizedBox();
    }

    final jobActivity = event.event;

    return FutureBuilderEx<JobAndCustomer>(
      // ignore: discarded_futures
      future: JobAndCustomer.fetch(job),
      builder:
          (context, jobAndCustomer) => SizedBox(
            height:
                view.heightPerMinute * (jobActivity?.durationInMinutes ?? 15),
            child: Card(
              color: SurfaceElevation.e6.color,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (jobActivity != null)
                            Circle(
                              color: jobActivity.jobActivity.status.color,
                              child: const Text(''),
                            ),
                          const SizedBox(width: 5),
                          HMBTextLine(jobAndCustomer!.job.summary),
                        ],
                      ),
                      Row(
                        children: [HMBTextLine(jobAndCustomer.customer.name)],
                      ),
                      Row(
                        children: [
                          HMBMapIcon(jobAndCustomer.site),
                          HMBPhoneIcon(
                            jobAndCustomer.bestPhoneNo ?? '',
                            sourceContext: SourceContext(
                              job: jobAndCustomer.job,
                              customer: jobAndCustomer.customer,
                            ),
                          ),
                          HMBMailToIcon(jobAndCustomer.bestEmailAddress),
                        ],
                      ),
                    ],
                  ),
                ),
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
