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
import 'job_event_ex.dart';
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
  /// - If [widget.initialEventId] is provided, fetch that event's date from DB.
  /// - Otherwise, use [DateTime.now()].
  Future<void> _initPage() async {
    var defaultDate = DateTime.now();

    // If an initialEventId is provided, fetch the event’s start date
    if (widget.initialEventId != null) {
      final dao = DaoJobEvent();
      final event = await dao.getById(widget.initialEventId);
      if (event != null) {
        defaultDate = event.startDate;
      }
    }

    // Calculate the initial page index from defaultDate
    var initialIndex = _getPageIndexForDate(defaultDate);
    // Clamp if it's below 0 (i.e., date < 2000-01-01)
    if (initialIndex < 0) {
      initialIndex = 0;
    }

    // Create the PageController using that initial index
    _pageController = PageController(initialPage: initialIndex);

    // Also set currentIndex and currentDate for our local state
    setState(() {
      // currentIndex = initialIndex;
      currentDate = _getDateForPage(initialIndex);
    });
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
                        currentDate = _getDateForPage(index);
                      });
                    },
                    itemBuilder: (context, index) {
                      final date = _getDateForPage(index);

                      switch (selectedView) {
                        case ScheduleView.month:
                          return MonthSchedule(
                            date,
                            defaultJob: widget.defaultJob,
                            onAdd: onAdd,
                            onUpdate: onUpdate,
                            onDelete: onDelete,
                          );
                        case ScheduleView.week:
                          return WeekSchedule(
                            date,
                            defaultJob: widget.defaultJob,
                            onAdd: onAdd,
                            onUpdate: onUpdate,
                            onDelete: onDelete,
                          );
                        case ScheduleView.day:
                          return DaySchedule(
                            date,
                            defaultJob: widget.defaultJob,
                            onAdd: onAdd,
                            onUpdate: onUpdate,
                            onDelete: onDelete,
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
  static final DateTime referenceDate = DateTime(2000);

  DateTime _getDateForPage(int pageIndex) {
    switch (selectedView) {
      case ScheduleView.day:
        // Day 0 = 2000-01-01
        return referenceDate.add(Duration(days: pageIndex));

      case ScheduleView.week:
        // Week 0 = 2000-01-01
        return referenceDate.add(Duration(days: pageIndex * 7));

      case ScheduleView.month:
        // Month 0 = 2000-01 (January 2000)
        // Month 1 = 2000-02 (February 2000)
        // Month 12 = 2001-01, etc.
        final totalMonths = pageIndex;
        final year = referenceDate.year + (totalMonths ~/ 12);
        final month = referenceDate.month + (totalMonths % 12); // ref.month = 1
        return DateTime(year, month);
    }
  }

  /// Calculates the page index for a given date based on the selected view.
  int _getPageIndexForDate(DateTime date) {
    // If date is before year 2000, clamp it or allow negative index
    // For example, to clamp to 0:
    if (date.isBefore(referenceDate)) return 0;

    switch (selectedView) {
      case ScheduleView.day:
        // difference in days from Jan 1, 2000
        return date.difference(referenceDate).inDays;

      case ScheduleView.week:
        // difference in weeks from Jan 1, 2000
        // integer division floors the value
        return date.difference(referenceDate).inDays ~/ 7;

      case ScheduleView.month:
        // difference in months from Jan 2000
        // e.g., Jan 2000 => 0, Feb 2000 => 1, Jan 2001 => 12
        final yearDiff = date.year - referenceDate.year;
        final monthDiff = date.month - referenceDate.month; // (1 - 1) for Jan
        return yearDiff * 12 + monthDiff;
    }
  }

  // -- EVENT CONTROLLER CALLBACKS -------------------------------------------

  // These are the callbacks that you pass down to child widgets. Depending on
  // your design, you might not need them in the parent if the child can do
  // everything itself. But if you want them, here they are:

  void onAdd(JobEventEx jobEventEx) {
    // Example: No in-memory state to update here, because each child fetches
    // its own events. If you want the parent to know, do so, then rely on
    // child re-fetching from DB.
  }

  void onUpdate(JobEventEx oldJob, JobEventEx updatedJob) {
    // Same note as onAdd
  }

  void onDelete(JobEventEx jobEventEx) {
    // Same note as onAdd
  }
}
