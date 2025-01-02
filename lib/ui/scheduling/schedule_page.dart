import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

// -- Example imports. Adapt for your project:
import '../../dao/dao_customer.dart';
import '../../dao/dao_job_event.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../util/app_title.dart';
import '../widgets/async_state.dart';
import '../widgets/hmb_icon_button.dart';
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

  /// Controls which page index is showing in the PageView
  late final PageController? _pageController;

  /// The date that corresponds to the currently displayed page
  DateTime currentDate = DateTime.now();

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
    // If you need to do something *before* building the UI, do it here.
    // For example, if you need to fetch something once for the entire page,
    // or check if widget.initialEventId should do something special.
    //
    // Since each child (DaySchedule, etc.) will fetch its own events,
    // we do not fetch anything else here.
    await _initPage();
  }

  /// Initialize the page controller with the correct starting index:
  /// - If [SchedulePage.initialEventId] is provided, fetch that event's date from DB.
  /// - Otherwise, use [DateTime.now()].
  Future<void> _initPage() async {
    currentDate = DateTime.now();

    // If an initialEventId is provided, fetch the event’s start date
    if (widget.initialEventId != null) {
      final dao = DaoJobEvent();
      final event = await dao.getById(widget.initialEventId);
      if (event != null) {
        currentDate = event.startDate;
      }
    }

    // Calculate the initial page index from defaultDate
    var initialIndex = _getPageIndexForDate(currentDate);
    // Clamp if it's below 0 (i.e., date < 2000-01-01)
    if (initialIndex < 0) {
      initialIndex = 0;
    }

    // Create the PageController using that initial index
    _pageController = PageController(initialPage: initialIndex);

    setState(() {});
  }

  @override
  void dispose() {
    _pageController?.dispose();
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
                  onHome: onHomePage,
                  child: PageView.builder(
                    key: ValueKey(selectedView),
                    controller: _pageController,
                    onPageChanged: (index) {
                      print('moving to $index');
                      setState(() {
                        if (!_isOnCurrentPage(currentDate, index)) {
                          currentDate = _getDateForPage(index);
                        }
                      });
                    },
                    itemBuilder: (context, index) {
                      final date = _getDateForPage(index);

                      switch (selectedView) {
                        case ScheduleView.month:
                          return MonthSchedule(
                            date,
                            defaultJob: widget.defaultJob,
                          );
                        case ScheduleView.week:
                          return WeekSchedule(
                            date,
                            defaultJob: widget.defaultJob,
                          );
                        case ScheduleView.day:
                          return DaySchedule(
                            date,
                            defaultJob: widget.defaultJob,
                          );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // -- NAVIGATION UTILS -----------------------------------------------------

  /// Show the left, right, and view droplist
  /// Show the navigation bar with left, right, view dropdown, and today button
  /// Show the navigation bar with left, right, view dropdown, and today button
  Widget _navigationRow() => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black, // Dark background for the navigation bar
          border: Border(
            bottom: BorderSide(color: Colors.grey[700]!), // Subtle border
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left navigation button
            HMBIconButton(
              icon: const Icon(Icons.arrow_left, color: Colors.white),
              onPressed: onPreviousPage,
              hint: 'Previous',
            ),

            const HMBSpacer(width: true),

            // Today button
            TextButton.icon(
              onPressed: onHomePage, // Go to today's date
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

            // Dropdown to select view type (Day, Week, Month)
            Flexible(
              child: HMBDroplist<ScheduleView>(
                selectedItem: () async => selectedView,
                items: (filter) async => ScheduleView.values,
                format: (view) => view.name,
                onChanged: (view) => setState(() {
                  selectedView = view!;

                  /// Calcuate the correct page index
                  /// so the new view shows the same date range.
                  print('PrePage: ${_pageController!.page}');
                  final newPage = _getPageIndexForDate(currentDate);

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _pageController.jumpToPage(newPage);
                    print('JumpTo: $newPage');
                  });
                }),
                title: 'View',
              ),
            ),
            const HMBSpacer(width: true),

            // Right navigation button
            HMBIconButton(
              icon: const Icon(Icons.arrow_right, color: Colors.white),
              onPressed: onNextPage,
              hint: 'Next',
            ),
          ],
        ),
      );

  /// Jump to "today" for whichever view is active
  Future<void> onHomePage() async {
    final today = DateTime.now();
    currentDate = today;
    final todayIndex = _getPageIndexForDate(today);
    await _pageController?.animateToPage(
      todayIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Go to the previous page in the PageView
  Future<void> onPreviousPage() async {
    int? currentIndex = _pageController?.page?.round() ?? 0;

    print('Navigated to page index: ${currentIndex - 1}');
    print('Navigated to date: ${_getDateForPage(currentIndex - 1)}');

    await _pageController?.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    currentIndex = _pageController?.page?.round();

    print('updated page index: $currentIndex');
  }

  /// Go to the next page in the PageView
  Future<void> onNextPage() async {
    await _pageController?.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Calculate the date for the given page index.
  /// The PageView controller doesn't accept -ve page index
  /// so we need to offset the page indexes to an arbitrary
  /// point in time. The user will not be able to scroll back
  /// before this point in time.
  /// We need to align to a monday so that week alignment works as
  /// expected.
  static final DateTime referenceDate = DateTime(2000, 1, 3);
  DateTime _getDateForPage(int pageIndex) {
    switch (selectedView) {
      case ScheduleView.day:
        // day 0 => referenceDate
        // day X => referenceDate + X days
        return _alignDay(
          referenceDate.add(Duration(days: pageIndex)),
        );

      case ScheduleView.week:
        // week 0 => referenceDate (aligned to Monday)
        // week X => referenceDate + (X * 7 days),
        final roughDate = referenceDate.add(Duration(days: pageIndex * 7));
        return _alignWeekStart(roughDate);

      case ScheduleView.month:
        // month 0 => referenceDate's month
        // month X => referenceDate + X months
        final totalMonths = pageIndex;
        final year = referenceDate.year + (totalMonths ~/ 12);
        final month = referenceDate.month + (totalMonths % 12);
        // Always show the 1st of that month
        return _alignMonthStart(DateTime(year, month));
    }
  }

  int _getPageIndexForDate(DateTime date) {
    // If date is before our referenceDate, clamp to 0 to avoid negative indices
    if (date.isBefore(referenceDate)) {
      return 0;
    }

    switch (selectedView) {
      case ScheduleView.day:
        final aligned = _alignDay(date);
        return aligned.difference(referenceDate).inDays;

      case ScheduleView.week:
        // Align to Monday before calculating the difference in days
        final aligned = _alignWeekStart(date);
        final daysSinceRef = aligned.difference(referenceDate).inDays;
        // integer division → # of weeks since reference
        return daysSinceRef ~/ 7;

      case ScheduleView.month:
        // Align to the 1st of the month
        final aligned = _alignMonthStart(date);
        final yearDiff = aligned.year - referenceDate.year;
        final monthDiff = aligned.month - referenceDate.month;
        return yearDiff * 12 + monthDiff;
    }
  }

  /// Checks if [dateToCheck] falls on the currently displayed page (day, week, month),
  /// given your current [selectedView] and [currentPageIndex].
  bool _isOnCurrentPage(DateTime dateToCheck, int currentPageIndex) {
    final range = _getPageRange(currentPageIndex);
    final start = range['start']!;
    final end = range['end']!;

    // Check: start <= dateToCheck < end
    return !dateToCheck.isBefore(start) && dateToCheck.isBefore(end);
  }

  /// Returns the start (inclusive) and end (exclusive) date range
  /// for the given [pageIndex] in [selectedView].
  ///
  /// Day View:   [dayStart, dayStart + 1 day)
  /// Week View:  [mondayStart, mondayStart + 7 days)
  /// Month View: [monthStart, nextMonthStart)
  ///
  /// Assumes you have alignment helpers like _alignDay(), _alignWeekStart(), _alignMonthStart().
  /// Also assumes _getDateForPage() is consistent with these alignments.
  Map<String, DateTime> _getPageRange(int pageIndex) {
    final date = _getDateForPage(pageIndex); // e.g., aligned date for that page

    switch (selectedView) {
      case ScheduleView.day:
        final start = _alignDay(date);
        final end = start.add(const Duration(days: 1));
        return {'start': start, 'end': end};

      case ScheduleView.week:
        // If date is already aligned to Monday, we can do this directly
        final start = _alignWeekStart(date);
        final end = start.add(const Duration(days: 7));
        return {'start': start, 'end': end};

      case ScheduleView.month:
        // If date is aligned to 1st of the month
        final start = _alignMonthStart(date);
        // The end is the 1st of the next month
        final nextMonth = (start.month == 12)
            ? DateTime(start.year + 1)
            : DateTime(start.year, start.month + 1);
        return {'start': start, 'end': nextMonth};
    }
  }

  /// Aligns the given date to the start of the day (i.e., midnight).
  DateTime _alignDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Aligns the given date to the start of its week (assuming Monday=1).
  /// If you want Monday as the first day of the week

  DateTime _alignWeekStart(DateTime date) {
    // Monday = 1, Tuesday=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7
    final dayOfWeek = date.weekday;
    final diff = dayOfWeek - DateTime.monday; // e.g. for Wed=3, diff=2
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: diff));
  }

  /// Aligns the given date to the first of the month.
  DateTime _alignMonthStart(DateTime date) => DateTime(date.year, date.month);
}
