// schedule_page.dart
import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_job_event.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../util/app_title.dart';
import '../widgets/async_state.dart';
import '../widgets/select/hmb_droplist.dart';
import 'day_schedule.dart';
import 'job_event_ex.dart';
import 'month_schedule.dart';
import 'schedule_helper.dart';
import 'week_schedule.dart';

class SchedulePage extends StatefulWidget with ScheduleHelper {
  SchedulePage({
    required this.dialogMode,
    super.key,
    this.defaultView = ScheduleView.day,
    DateTime? initialDate,
    this.preSelectedJobId,
    this.initialEventId,
  }) : initialDate = initialDate ?? DateTime.now();

  final bool dialogMode;

  /// The view to show: day, week, or month
  final ScheduleView defaultView;

  /// Which date to show first (e.g., "today" or the date of a next event)
  final DateTime initialDate;

  /// If we came from a specific job, we can auto-populate that in the JobEventDialog
  final int? preSelectedJobId;

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
  int? initialEventId;

  @override
  void initState() {
    super.initState();
    setAppTitle('Schedule');
    eventController = EventController();
    // Use the passed-in arguments to initialize
    selectedView = widget.defaultView;
    currentDate = widget.initialDate;
    preSelectedJobId = widget.preSelectedJobId;
    initialEventId = widget.initialEventId;
  }

  @override
  Future<void> asyncInitState() async {
    await _loadEventsFromDb();

    // If we have an initialEventId, scroll or jump to it.
    if (initialEventId != null) {
      final eventData = eventController
          .getEventsOnDay(currentDate)
          .where((e) => e.event?.jobEvent.id == initialEventId)
          .toList();
      // If found, you might do something like open DayView or set page offset
      // Or call setState to highlight that date
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: HMBDroplist<ScheduleView>(
                      selectedItem: () async => selectedView,
                      items: (filter) async => ScheduleView.values,
                      format: (view) => view.name,
                      onChanged: (view) => setState(() {
                        selectedView = view!;
                      }),
                      title: 'View',
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  key: ValueKey(
                      selectedView), // ensure a rebuild when the view changes.
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
                          onAdd: onAdd, onUpdate: onUpdate, onDelete: onDelete),
                      ScheduleView.week => WeekSchedule(date,
                          onAdd: onAdd, onUpdate: onUpdate, onDelete: onDelete),
                      ScheduleView.day => DaySchedule(date,
                          onAdd: onAdd, onUpdate: onUpdate, onDelete: onDelete),
                    };
                  },
                ),
              ),
            ],
          ),
        ),
      ));

  void onAdd(JobEventEx jobEventEx) {
    // Add to our in-memory list & calendar
    setState(() {
      eventController.add(jobEventEx.eventData);
    });
  }

  void onUpdate(JobEventEx oldJob, JobEventEx updatedJob) {
    // 2) Remove old from the calendar, re-add updated
    eventController
      ..remove(oldJob.eventData)
      ..add(updatedJob.eventData);

    setState(() {});
  }

  void onDelete(JobEventEx jobEventEx) {
    setState(() {
      // Remove from local memory & calendar
      eventController.remove(jobEventEx.eventData);
    });
  }

  /// Calculates the date for the given page index.
  DateTime _getDateForPage(int pageIndex) {
    final today = DateTime.now();
    return switch (selectedView) {
      ScheduleView.month => DateTime(today.year, today.month + pageIndex),
      ScheduleView.week => today.add(Duration(days: 7 * pageIndex)),
      ScheduleView.day => today.add(Duration(days: pageIndex)),
    };
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
