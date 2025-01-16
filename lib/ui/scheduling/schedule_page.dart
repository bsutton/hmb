import 'dart:async';

import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';

// -- Example imports. Adapt for your project:
import '../../dao/dao_customer.dart';
import '../../dao/dao_job_activity.dart';
import '../../dao/dao_system.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../entity/operating_hours.dart';
import '../../util/app_title.dart';
import '../../util/date_time_ex.dart';
import '../../util/local_date.dart';
import '../widgets/async_state.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/hmb_toggle.dart';
import '../widgets/layout/hmb_spacer.dart';
import '../widgets/select/hmb_droplist.dart';
import 'day_schedule.dart'; // Our DaySchedule stateful widget
import 'desktop_swipe.dart';
import 'job_activity_ex.dart';
import 'month_schedule.dart'; // Our MonthSchedule stateful widget
import 'schedule_helper.dart';
import 'week_schedule.dart'; // Our WeekSchedule stateful widget

/// The enum for the three possible views
enum ScheduleView { month, week, day }

/// Calculate the date for the given page index.
/// The PageView controller doesn't accept -ve page index
/// so we need to offset the page indexes to an arbitrary
/// point in time. The user will not be able to scroll back
/// before this point in time.
/// We need to align to a monday so that week alignment works as
/// expected.
final _referenceDate = LocalDate(2000, 1, 3);

/// A convenience data class for combining a [Job] and its [Customer].
class JobAndCustomer {
  JobAndCustomer(this.job, this.customer);

  static Future<JobAndCustomer> fetch(Job job) async {
    final customer = await DaoCustomer().getByJob(job.id);
    return JobAndCustomer(job, customer!);
  }

  final Job job;
  final Customer customer;
}

/// The main schedule page. This is the "shell" that holds a [PageView] of either
/// [DaySchedule], [WeekSchedule], or [MonthSchedule].
class SchedulePage extends StatefulWidget with ScheduleHelper {
  const SchedulePage({
    required this.dialogMode,
    super.key,
    this.defaultView = ScheduleView.day,
    this.defaultJob,
    this.initialActivityId,
  });

  /// If true, we show an [AppBar], otherwise we might show a different UI
  final bool dialogMode;

  /// The initial view to show: day, week, or month
  final ScheduleView defaultView;

  /// If we came from a specific job, auto-populate in the activity dialog
  final int? defaultJob;

  /// If we want the schedule to jump to a specific activity
  final int? initialActivityId;

  @override
  State<SchedulePage> createState() => SchedulePageState();
}

///
/// [SchedulePageState]
///
class SchedulePageState extends AsyncState<SchedulePage> {
  late ScheduleView selectedView;
  bool showExtendedHours = false;

  final monthKey = GlobalKey<MonthViewState<JobActivityEx>>();
  final weekKey = GlobalKey<WeekViewState>();
  final dayKey = GlobalKey<DayViewState>();

  /// Controls which page index is showing in the PageView
  // late final PageController? _pageControllerX;

  /// The date that corresponds to the first date on currently displayed page
  LocalDate currentFirstDateOnPage = LocalDate.today();

  /// The current date that the user is focused on.
  /// Used to help select the [currentFirstDateOnPage] when
  /// moving from a broader date range (e.g. month) to a narrow
  /// date range (e.g. day)
  LocalDate focusDate = LocalDate.today();

  /// A guard to prevent infinite `_onPageChanged` loops if we call jumpToPage inside it.
  bool _isAdjustingPage = false;

  late final OperatingHours operatingHours;

  /// e.g., if you want to highlight a certain job ID
  int? preSelectedJobId;

  @override
  void initState() {
    setAppTitle('Schedule');

    selectedView = widget.defaultView;
    preSelectedJobId = widget.defaultJob;

    super.initState();
  }

  @override
  Future<void> asyncInitState() async {
    operatingHours = (await DaoSystem().get()).getOperatingHours();
    if (operatingHours.noOpenDays()) {
      HMBToast.error(
          "Before you Schedule a job, you must first set your opening hours from the 'System | Business' page.");
      if (mounted) {
        context.go('/jobs');
      }
    }
    await _initPage();
  }

  void showDateOnView(ScheduleView view, LocalDate date) {
    selectedView = view;
    unawaited(_onPageChanged(date));
  }

  /// Initialize the page controller with the correct starting index:
  /// - If [SchedulePage.initialActivityId] is provided, fetch that activities' date from DB.
  /// - Otherwise, use [DateTime.now()].
  Future<void> _initPage() async {
    currentFirstDateOnPage =
        await operatingHours.getNextOpenDate(LocalDate.today());

    // If an initialActivityId is provided, fetch the activities' start date
    if (widget.initialActivityId != null) {
      final dao = DaoJobActivity();
      final activity = await dao.getById(widget.initialActivityId);
      if (activity != null) {
        currentFirstDateOnPage = activity.start.toLocalDate();
      }
    }

    if (currentFirstDateOnPage.isBefore(_referenceDate)) {
      currentFirstDateOnPage = _referenceDate;
    }

    focusDate = currentFirstDateOnPage;
    print('focusDate: $focusDate');

    // Create the PageController using that initial index
    // _pageControllerX = PageController(initialPage: initialIndex);

    setState(() {});
  }

  @override
  void dispose() {
    // _pageControllerX?.dispose();
    super.dispose();
  }

  // BUILD
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.dialogMode ? AppBar() : null,
        body: FutureBuilderEx(
          future: initialised,
          builder: (context, _) => Column(
            children: [
              _navigationRow(),
              Expanded(
                child: DesktopSwipe(
                  onNext: onNextPage,
                  onPrevious: onPreviousPage,
                  onHome: onTodayPage,
                  child: _buildCalendar(),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildCalendar() {
    final calendarViews = <Widget>[
      MonthSchedule(
          schedulePageState: this,
          monthKey: monthKey,
          currentFirstDateOnPage,
          onPageChange: (date) async => _onPageChanged(date),
          defaultJob: widget.defaultJob,
          showWeekends: showExtendedHours),
      WeekSchedule(
        currentFirstDateOnPage,
        weekKey: weekKey,
        defaultJob: widget.defaultJob,
        onPageChange: (date) async => _onPageChanged(date),
        showExtendedHours: showExtendedHours,
      ),
      DaySchedule(
        dayKey: dayKey,
        currentFirstDateOnPage,
        defaultJob: widget.defaultJob,
        showExtendedHours: showExtendedHours,
        onPageChange: (date) async => _onPageChanged(date),
      ),
    ];

    // Find the selected view and remove it from the list
    Widget selectedWidget;
    switch (selectedView) {
      case ScheduleView.month:
        selectedWidget = calendarViews.removeAt(0);
      case ScheduleView.week:
        selectedWidget = calendarViews.removeAt(1);
      case ScheduleView.day:
        selectedWidget = calendarViews.removeAt(2);
    }

    // Create a new list with the selected view at the beginning
    final orderedViews = [
      Positioned.fill(
          child: Visibility(
              maintainState: true, visible: false, child: calendarViews[0])),
      Positioned.fill(
          child: Visibility(
              maintainState: true, visible: false, child: calendarViews[1])),

      /// last widget is on top
      Positioned.fill(child: selectedWidget),
    ];

    return Stack(children: orderedViews);
  }

  Future<LocalDate> _onPageChanged(LocalDate targetDate) async {
    // If we just called jumpToDate() internally, skip this invocation.
    if (_isAdjustingPage) {
      return currentFirstDateOnPage;
    }
    print('onPageChanged targetDate $targetDate');

    // Determine if user swiped forward or backward
    final isForward = targetDate.isAfter(currentFirstDateOnPage);

    var skipTo = false;

    // Only skip closed days if we are in DAY view & not showExtendedHours
    if (selectedView == ScheduleView.day && !showExtendedHours) {
      final newDate = isForward
          ? (await operatingHours.getNextOpenDate(targetDate))
          : (await operatingHours.getPreviousOpenDate(targetDate));

      if (newDate != targetDate) {
        /// skip to the next/prev open date.
        targetDate = newDate;
        skipTo = true;
      }
    }

    // If we're here, either the date is open or we’re in week/month view.
    // Just update your state to reflect the new date.
    setState(() {
      currentFirstDateOnPage = targetDate;
    });

    if (skipTo) {
      // Prevent re-entrant calls
      _isAdjustingPage = true;

      print('onPageChanged jumpToDate $targetDate');
      await _jumpToDate(targetDate);
      _isAdjustingPage = false;
    }
    focusDate = currentFirstDateOnPage;
    print('onPageChanged currentFirstDateOnPage $currentFirstDateOnPage');
    return currentFirstDateOnPage;
  }

  Future<void> _jumpToDate(LocalDate targetDate) async {
    const duration = Duration(milliseconds: 300);
    const curve = Curves.easeInOut;

    switch (selectedView) {
      case ScheduleView.month:
        await monthKey.currentState!.animateToMonth(targetDate.toDateTime(),
            duration: duration, curve: curve);
      case ScheduleView.week:
        await weekKey.currentState!.animateToWeek(targetDate.toDateTime(),
            duration: duration, curve: curve);
      case ScheduleView.day:
        await dayKey.currentState!.animateToDate(targetDate.toDateTime(),
            duration: duration, curve: curve);
    }
  }

  void previousPage() {
    const duration = Duration(milliseconds: 300);
    const curve = Curves.easeInOut;

    switch (selectedView) {
      case ScheduleView.month:
        monthKey.currentState!.previousPage(duration: duration, curve: curve);
      case ScheduleView.week:
        weekKey.currentState!.previousPage(duration: duration, curve: curve);
      case ScheduleView.day:
        dayKey.currentState!.previousPage(duration: duration, curve: curve);
    }
  }

  void nextPage() {
    const duration = Duration(milliseconds: 300);
    const curve = Curves.easeInOut;

    switch (selectedView) {
      case ScheduleView.month:
        monthKey.currentState!.nextPage(duration: duration, curve: curve);
      case ScheduleView.week:
        weekKey.currentState!.nextPage(duration: duration, curve: curve);
      case ScheduleView.day:
        dayKey.currentState!.nextPage(duration: duration, curve: curve);
    }
  }

  // -- NAVIGATION UTILS -----------------------------------------------------

  /// Show the left, right, and view droplist
  /// Show the navigation bar with left, right, view dropdown, and today button
  /// Show the navigation bar with left, right, view dropdown, and today button
  Widget _navigationRow() => Padding(
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: onTodayPage, // Go to today's date
              icon: const Icon(Icons.today, color: Colors.blue),
              label: const Text(
                'Today',
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor:
                    Colors.grey[900], // Slightly lighter than black
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.blue.shade300),
                ),
              ),
            ),
            const HMBSpacer(width: true),

            // Extended hours button
            HMBToggle(
                label: 'Extended',
                tooltip: 'Show full 24 hrs',
                initialValue: false,
                onChanged: (value) {
                  setState(() {
                    showExtendedHours = value;
                  });
                }),
            const HMBSpacer(width: true),

            // Dropdown to select view type (Day, Week, Month)
            Flexible(
              child: HMBDroplist<ScheduleView>(
                selectedItem: () async => selectedView,
                items: (filter) async => ScheduleView.values,
                format: (view) => view.name,
                onChanged: (view) async {
                  focusDate = await _adjustFocusDate(selectedView);
                  selectedView = view!;

                  /// Force the new view to the same date
                  WidgetsBinding.instance.scheduleFrameCallback((_) async {
                    await _jumpToDate(currentFirstDateOnPage);
                  });
                  setState(() {});
                },
                title: 'View',
              ),
            ),
          ],
        ),
      );

  /// Jump to "today" for whichever view is active
  Future<void> onTodayPage() async {
    if (showExtendedHours) {
      currentFirstDateOnPage = LocalDate.today();
    } else {
      currentFirstDateOnPage =
          await operatingHours.getNextOpenDate(LocalDate.today());
    }
    print('moving to $currentFirstDateOnPage');
    _isAdjustingPage = true;
    await _jumpToDate(currentFirstDateOnPage);
    _isAdjustingPage = false;
    setState(() {});
  }

  /// Go to the previous page in the PageView
  Future<void> onPreviousPage() async {
    previousPage();
  }

  /// Go to the next page in the PageView
  Future<void> onNextPage() async {
    nextPage();
  }

  Future<LocalDate> _adjustFocusDate(
    ScheduleView fromView,
  ) async {
    final rangeStart = currentFirstDateOnPage;
    final LocalDate rangeEnd;

    // Determine the end of the range based on the selected view
    switch (fromView) {
      case ScheduleView.month:
        rangeEnd = currentFirstDateOnPage.addMonths(1).subtractDays(1);
      case ScheduleView.week:
        rangeEnd = currentFirstDateOnPage.addDays(6);
      case ScheduleView.day:
        rangeEnd = currentFirstDateOnPage; // Day view has a single-day range
    }

    LocalDate revisedDate;

    // If focusDate is within the range, return focusDate
    if (focusDate.isAfterOrEqual(rangeStart) &&
        focusDate.isBeforeOrEqual(rangeEnd)) {
      revisedDate = focusDate;
    } else {
      // Otherwise, return the start of the range
      revisedDate = rangeStart;
    }

    if (!(await operatingHours.isOpen(revisedDate))) {
      revisedDate = await operatingHours.getNextOpenDate(revisedDate);
    }

    if (focusDate != revisedDate) {
      // we must have changed pages so the first date
      // must change.
      currentFirstDateOnPage = revisedDate;
    }
    return revisedDate;
  }
}
