import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';

// -- Example imports. Adapt for your project:
import '../../dao/dao_customer.dart';
import '../../dao/dao_job_event.dart';
import '../../dao/dao_system.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../entity/system.dart';
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
import 'month_schedule.dart'; // Our MonthSchedule stateful widget
import 'schedule_helper.dart';
import 'week_schedule.dart'; // Our WeekSchedule stateful widget

/// The enum for the three possible views
enum ScheduleView { month, week, day }

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
    this.initialEventId,
  });

  /// If true, we show an [AppBar], otherwise we might show a different UI
  final bool dialogMode;

  /// The initial view to show: day, week, or month
  final ScheduleView defaultView;

  /// If we came from a specific job, auto-populate in the event dialog
  final int? defaultJob;

  /// If we want the schedule to jump to a specific event
  final int? initialEventId;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends AsyncState<SchedulePage, void> {
  late ScheduleView selectedView;
  bool showExtendedHours = false;

  final monthKey = GlobalKey<MonthViewState>();
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
    operatingHours = (await DaoSystem().get())!.getOperatingHours();
    if (operatingHours.noOpenDays()) {
      HMBToast.error(
          "Before you Schedule a job, you must first set your opening hours from the 'System | Business' page.");
      if (mounted) {
        context.go('/jobs');
      }
    }
    await _initPage();
  }

  /// Initialize the page controller with the correct starting index:
  /// - If [SchedulePage.initialEventId] is provided, fetch that event's date from DB.
  /// - Otherwise, use [DateTime.now()].
  Future<void> _initPage() async {
    currentFirstDateOnPage =
        await operatingHours.getNextOpenDate(LocalDate.today());

    // If an initialEventId is provided, fetch the event’s start date
    if (widget.initialEventId != null) {
      final dao = DaoJobEvent();
      final event = await dao.getById(widget.initialEventId);
      if (event != null) {
        currentFirstDateOnPage = event.start.toLocalDate();
      }
    }

    if (currentFirstDateOnPage.isBefore(referenceDate)) {
      currentFirstDateOnPage = referenceDate;
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
    print('page changed to $targetDate');
    // If we just called jumpToDate() internally, skip this invocation.
    if (_isAdjustingPage) {
      _isAdjustingPage = false;
      return currentFirstDateOnPage;
    }

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

      await _jumpToDate(targetDate);
    }
    focusDate = currentFirstDateOnPage;
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
            // // Left navigation button
            // if (isNotMobile)
            //   HMBIconButton(
            //     icon: const Icon(Icons.arrow_left, color: Colors.white),
            //     onPressed: onPreviousPage,
            //     hint: 'Previous',
            //   ),

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

            // // Right navigation button
            // if (isNotMobile)
            //   HMBIconButton(
            //     icon: const Icon(Icons.arrow_right, color: Colors.white),
            //     onPressed: onNextPage,
            //     hint: 'Next',
            //   ),
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
    await _jumpToDate(currentFirstDateOnPage);
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

  /// Calculate the date for the given page index.
  /// The PageView controller doesn't accept -ve page index
  /// so we need to offset the page indexes to an arbitrary
  /// point in time. The user will not be able to scroll back
  /// before this point in time.
  /// We need to align to a monday so that week alignment works as
  /// expected.
  final referenceDate = LocalDate(2000, 1, 3);
  // LocalDate _getDateForPage(int pageIndex) {
  //   switch (selectedView) {
  //     case ScheduleView.day:
  //       // day 0 => referenceDate
  //       // day X => referenceDate + X days
  //       return _alignDay(
  //         referenceDate.add(Duration(days: pageIndex)),
  //       );

  //     case ScheduleView.week:
  //       // week 0 => referenceDate (aligned to Monday)
  //       // week X => referenceDate + (X * 7 days),
  //       final roughDate = referenceDate.add(Duration(days: pageIndex * 7));
  //       return _alignWeekStart(roughDate);

  //     case ScheduleView.month:
  //       // month 0 => referenceDate's month
  //       // month X => referenceDate + X months
  //       final totalMonths = pageIndex;
  //       final year = referenceDate.year + (totalMonths ~/ 12);
  //       final month = referenceDate.month + (totalMonths % 12);
  //       // Always show the 1st of that month
  //       return _alignMonthStart(LocalDate(year, month));
  //   }
  // }

  // int _getPageIndexForDate(LocalDate date) {
  //   // If date is before our referenceDate, clamp to 0 to avoid negative indices
  //   if (date.isBefore(referenceDate)) {
  //     return 0;
  //   }

  //   switch (selectedView) {
  //     case ScheduleView.day:
  //       final aligned = _alignDay(date);
  //       return aligned.difference(referenceDate).inDays;

  //     case ScheduleView.week:
  //       // Align to Monday before calculating the difference in days
  //       final aligned = _alignWeekStart(date);
  //       final daysSinceRef = aligned.difference(referenceDate).inDays;
  //       // integer division → # of weeks since reference
  //       return daysSinceRef ~/ 7;

  //     case ScheduleView.month:
  //       // Align to the 1st of the month
  //       final aligned = _alignMonthStart(date);
  //       final yearDiff = aligned.year - referenceDate.year;
  //       final monthDiff = aligned.month - referenceDate.month;
  //       return yearDiff * 12 + monthDiff;
  //   }
  // }

  /// Checks if [dateToCheck] falls on the currently displayed page (day, week, month),
  /// given your current [fromView] and [currentPageIndex].
  // bool _isOnCurrentPage(LocalDate dateToCheck, int currentPageIndex) {
  //   final range = _getPageRange(currentPageIndex);
  //   final start = range['start']!;
  //   final end = range['end']!;

  //   // Check: start <= dateToCheck < end
  //   return !dateToCheck.isBefore(start) && dateToCheck.isBefore(end);
  // }

  /// Returns the start (inclusive) and end (exclusive) date range
  /// for the given [pageIndex] in [fromView].
  ///
  /// Day View:   [dayStart, dayStart + 1 day)
  /// Week View:  [mondayStart, mondayStart + 7 days)
  /// Month View: [monthStart, nextMonthStart)
  ///
  /// Assumes you have alignment helpers like _alignDay(), _alignWeekStart(), _alignMonthStart().
  /// Also assumes _getDateForPage() is consistent with these alignments.
  // Map<String, LocalDate> _getPageRange(int pageIndex) {
  //   final date = _getDateForPage(pageIndex); // e.g., aligned date for that page

  //   switch (selectedView) {
  //     case ScheduleView.day:
  //       final start = _alignDay(date);
  //       final end = start.add(const Duration(days: 1));
  //       return {'start': start, 'end': end};

  //     case ScheduleView.week:
  //       // If date is already aligned to Monday, we can do this directly
  //       final start = _alignWeekStart(date);
  //       final end = start.add(const Duration(days: 7));
  //       return {'start': start, 'end': end};

  //     case ScheduleView.month:
  //       // If date is aligned to 1st of the month
  //       final start = _alignMonthStart(date);
  //       // The end is the 1st of the next month
  //       final nextMonth = (start.month == 12)
  //           ? LocalDate(start.year + 1)
  //           : LocalDate(start.year, start.month + 1);
  //       return {'start': start, 'end': nextMonth};
  //   }
  // }

  /// Aligns the given date to the start of the day (i.e., midnight).
  // LocalDate _alignDay(LocalDate date) =>
  //     LocalDate(date.year, date.month, date.day);

  /// Aligns the given date to the start of its week (assuming Monday=1).
  /// If you want Monday as the first day of the week

  // LocalDate _alignWeekStart(LocalDate date) {
  //   // Monday = 1, Tuesday=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7
  //   final dayOfWeek = date.weekday;
  //   final diff = dayOfWeek - DateTime.monday; // e.g. for Wed=3, diff=2
  //   return LocalDate(date.year, date.month, date.day)
  //       .subtract(Duration(days: diff));
  // }

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
