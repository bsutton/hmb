import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_job_event.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../util/app_title.dart';
import '../widgets/async_state.dart';
import '../widgets/hmb_icon_button.dart';
import '../widgets/select/hmb_droplist.dart';
import 'day_schedule.dart';
import 'desktop_swipe.dart';
import 'job_event_ex.dart';
import 'month_schedule.dart';
import 'schedule_helper.dart';
import 'week_schedule.dart';

class SchedulePage extends StatefulWidget with ScheduleHelper {
  SchedulePage({
    required this.dialogMode,
    super.key,
    this.defaultView = ScheduleView.day,
    this.defaultJob,
    this.initialEventId,
  }) ;

  final bool dialogMode;

  /// The view to show: day, week, or month
  final ScheduleView defaultView;


  /// If we came from a specific job, we can auto-populate that in the JobEventDialog
  final int? defaultJob;

  /// If we want the schedule to jump to a specific event
  final int? initialEventId;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

enum ScheduleView { month, week, day }

class _SchedulePageState extends AsyncState<SchedulePage, void> {
  late ScheduleView selectedView;
  late final EventController<JobEventEx> eventController;

  final PageController _pageController = PageController();
  DateTime currentDate = DateTime.now();

  int? preSelectedJobId;

  @override
  void initState() {
    super.initState();
    setAppTitle('Schedule');
    eventController = EventController();

    selectedView = widget.defaultView;
    preSelectedJobId = widget.defaultJob;
  }

  @override
  Future<void> asyncInitState() async {
    await _loadEventsFromDb();

    // Scroll to initial event if specified
    if (widget.initialEventId != null) {
      final events = eventController
          .getEventsOnDay(currentDate)
          .where((e) => e.event?.jobEvent.id == widget.initialEventId)
          .toList();
      if (events.isNotEmpty) {
        setState(() {
          currentDate = events.first.date;
        });
      }
    }
  }

  @override
  void dispose() {
    eventController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadEventsFromDb() async {
    final dao = DaoJobEvent();
    final jobEvents = await dao.getAll();

    final eventData = <CalendarEventData<JobEventEx>>[];
    for (final jobEvent in jobEvents) {
      eventData.add((await JobEventEx.fromEvent(jobEvent)).eventData);
    }

    eventController
      ..removeAll(eventController.allEvents)
      ..addAll(eventData);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.dialogMode ? AppBar() : null,
        body: FutureBuilderEx(
          future: initialised,
          builder: (context, _) => CalendarControllerProvider<JobEventEx>(
            controller: eventController,
            child: Column(
              children: [
                navigation(),
                Expanded(
                  child: DesktopSwipe(
                    onNext: () async {
                      await onNextPage();
                    },
                    onPrevious: () async {
                      await onPreviousPage();
                    },
                    onHome: () async {
                      await onHomePage();
                    },
                    child: PageView.builder(
                      key: ValueKey(selectedView),
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          currentDate = _getDateForPage(index);
                        });
                      },
                      itemBuilder: (context, index) {
                        final date = _getDateForPage(index);
                        return switch (selectedView) {
                          ScheduleView.month => MonthSchedule(date,
                              defaultJob: widget.defaultJob,
                              onAdd: onAdd,
                              onUpdate: onUpdate,
                              onDelete: onDelete),
                          ScheduleView.week => WeekSchedule(date,
                              defaultJob: widget.defaultJob,
                              onAdd: onAdd,
                              onUpdate: onUpdate,
                              onDelete: onDelete),
                          ScheduleView.day => DaySchedule(date,
                              defaultJob: widget.defaultJob,
                              onAdd: onAdd,
                              onUpdate: onUpdate,
                              onDelete: onDelete),
                        };
                      },
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      );

  Future<void> onHomePage() async {
    final today = DateTime.now();
    final todayIndex = _getPageIndexForDate(today);

    await _pageController.animateToPage(
      todayIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> onPreviousPage() async {
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> onNextPage() async {
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Show left/right nav buttons and the droplist for the view (day,week month)
  Widget navigation() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          HMBIconButton(
              icon: const Icon(Icons.arrow_left),
              onPressed: () async {
                await onPreviousPage();
              },
              hint: 'left'),
          HMBDroplist<ScheduleView>(
            selectedItem: () async => selectedView,
            items: (filter) async => ScheduleView.values,
            format: (view) => view.name,
            onChanged: (view) => setState(() {
              selectedView = view!;
            }),
            title: 'View',
          ),
          HMBIconButton(
            icon: const Icon(Icons.arrow_right),
            onPressed: () async {
              await onNextPage();
            },
            hint: 'right',
          ),
        ],
      );

  void onAdd(JobEventEx jobEventEx) {
    setState(() {
      eventController.add(jobEventEx.eventData);
    });
  }

  void onUpdate(JobEventEx oldJob, JobEventEx updatedJob) {
    eventController
      ..remove(oldJob.eventData)
      ..add(updatedJob.eventData);

    setState(() {});
  }

  void onDelete(JobEventEx jobEventEx) {
    setState(() {
      eventController.remove(jobEventEx.eventData);
    });
  }

  /// Calculate the date for the given page index.
  DateTime _getDateForPage(int pageIndex) {
    final today = DateTime.now();
    return switch (selectedView) {
      ScheduleView.month => DateTime(today.year, today.month + pageIndex),
      ScheduleView.week => today.add(Duration(days: 7 * pageIndex)),
      ScheduleView.day => today.add(Duration(days: pageIndex)),
    };
  }

  /// Calculates the page index for a given date based on the selected view.
  int _getPageIndexForDate(DateTime date) {
    final referenceDate = DateTime.now();

    switch (selectedView) {
      case ScheduleView.day:
        return date.difference(referenceDate).inDays;
      case ScheduleView.week:
        return (date.difference(referenceDate).inDays / 7).floor();
      case ScheduleView.month:
        return (date.year - referenceDate.year) * 12 +
            (date.month - referenceDate.month);
    }
  }
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
