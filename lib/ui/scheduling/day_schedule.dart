/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:math';

import 'package:calendar_view/calendar_view.dart';
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao.g.dart';
import '../../entity/flutter_extensions/job_activity_status_ex.dart';
import '../../entity/operating_hours.dart';
import '../../entity/system.dart';
import '../../util/dart/date_time_ex.dart';
import '../../util/dart/format.dart';
import '../../util/dart/local_date.dart';
import '../crud/job/full_page_list_job_card.dart';
import '../dialog/dialog.g.dart';
import '../widgets/circle.dart';
import '../widgets/hmb_link_internal.dart';
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
  final LocalDate initialDate;
  final int? defaultJob;
  final bool showExtendedHours;
  final Future<LocalDate> Function(LocalDate targetDate) onPageChange;
  final Key dayKey;

  DaySchedule(
    this.initialDate, {
    required this.defaultJob,
    required this.showExtendedHours,
    required this.onPageChange,
    required this.dayKey,
    super.key,
  });

  @override
  State<DaySchedule> createState() => _DayScheduleState();
}

class _DayScheduleState extends DeferredState<DaySchedule> {
  late final EventController<JobActivityEx> _dayController;
  late final System system;
  late final OperatingHours operatingHours;
  var _hasActivitiesInExtendedHours = false;
  // New state variables to hold the computed bounds when there are
  //extended activities.
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

  /// Fetch activities for [currentDate] from DB and compute extended
  /// hour bounds if needed.
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
        // Assuming jobActivity has 'start' and 'end' DateTime properties.
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
    // If operating hours are not defined, we treat it as a non-operating day.
    if (dayOperating.start == null || dayOperating.end == null) {
      _hasActivitiesInExtendedHours = false;
      _computedStartHour = null;
      _computedEndHour = null;
    } else {
      final operatingStartHour = dayOperating.start!.hour;
      final operatingEndHour = dayOperating.end!.hour;
      // Default buffered operating hours with a 1-hour buffer.
      final int defaultStart = max(0, operatingStartHour - buffer);
      final int defaultEnd = min(24, operatingEndHour + buffer);

      if (foundExtended) {
        _hasActivitiesInExtendedHours = true;
        // Apply a 1-hour buffer to extended event bounds.
        _computedStartHour = min(
          defaultStart,
          max(0, earliestExtendedHour - buffer),
        );
        _computedEndHour = max(
          defaultEnd,
          min(24, latestExtendedHour + buffer),
        );
      } else {
        _hasActivitiesInExtendedHours = false;
        _computedStartHour = null;
        _computedEndHour = null;
      }
    }

    print('Extended hours: $_hasActivitiesInExtendedHours');
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
              // ignore: discarded_futures
              onPageChange: (date, _) => _onPageChange(date),
              startHour: _getStartHour(),
              endHour: _getEndHour(),
              key: widget.dayKey,
              initialDay: currentDate.toDateTime(),
              dateStringBuilder: dayTitle,
              timeStringBuilder: (date, {secondaryDate}) =>
                  formatTime(date, 'ha').toLowerCase(),
              heightPerMinute: 1.8,
              eventTileBuilder:
                  (date, events, boundary, startDuration, endDuration) =>
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
    // If the extended toggle is on, show the full day.
    if (widget.showExtendedHours) {
      return 0;
    }
    final dayOperating = system.getOperatingHours().day(
      DayName.fromDate(currentDate),
    );
    // If operating hours are not defined (non-operating day),
    //show the full day.
    if (dayOperating.start == null || dayOperating.end == null) {
      return 0;
    }
    // If there are extended activities, use the computed start hour.
    if (_hasActivitiesInExtendedHours && _computedStartHour != null) {
      return _computedStartHour!;
    }
    // Otherwise, return the operating start hour with a 1-hour buffer.
    const buffer = 1;
    final operatingStartHour = dayOperating.start!.hour;
    return max(0, operatingStartHour - buffer);
  }

  /// Determine the end hour for the day view.
  int _getEndHour() {
    // If the extended toggle is on, show the full day.
    if (widget.showExtendedHours) {
      return 24;
    }
    final dayOperating = system.getOperatingHours().day(
      DayName.fromDate(currentDate),
    );
    // If operating hours are not defined (non-operating day),
    //show the full day.
    if (dayOperating.start == null || dayOperating.end == null) {
      return 24;
    }
    // If there are extended activities, use the computed end hour.
    if (_hasActivitiesInExtendedHours && _computedEndHour != null) {
      return _computedEndHour!;
    }
    // Otherwise, return the operating end hour with a 1-hour buffer.
    const buffer = 1;
    final operatingEndHour = dayOperating.end!.hour;
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
      builder: (context, jobAndCustomer) {
        final jobName = jobAndCustomer!.job.summary;
        final note = jobActivity?.jobActivity.notes;
        var displayText = jobName;
        if (note != null && note.trim().isNotEmpty) {
          final firstLine = note.trim().split('\n').first;
          displayText = '$jobName / $firstLine';
        }

        return SizedBox(
          height: view.heightPerMinute * (jobActivity?.durationInMinutes ?? 15),
          child: _buildCard(jobActivity, displayText, jobAndCustomer),
        );
      },
    );
  }

  Card _buildCard(
    JobActivityEx? jobActivity,
    String displayText,
    JobAndCustomer jobAndCustomer,
  ) => Card(
    color: SurfaceElevation.e6.color,
    child: Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4, right: 8),
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wrap the first two rows in a Row so we can have
            //a two-row column at the end.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Column with job activity and customer name.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (jobActivity != null)
                            Circle(
                              color: jobActivity.jobActivity.status.color,
                              child: const Text(''),
                            ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              displayText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [HMBTextLine(jobAndCustomer.customer.name)],
                      ),
                    ],
                  ),
                ),
                // Right: Column spanning two rows with the job link.
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HMBLinkInternal(
                      label: 'Job: #${jobAndCustomer.job.id}',
                      navigateTo: () async =>
                          FullPageListJobCard(jobAndCustomer.job),
                    ),
                  ],
                ),
              ],
            ),
            // Action icons row.
            Row(
              children: [
                HMBMapIcon(
                  jobAndCustomer.site,
                  onMapClicked: () async {
                    await DaoJob().markActive(jobAndCustomer.job.id);
                  },
                ),
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
  );

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
