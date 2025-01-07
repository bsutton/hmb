import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_job_event.dart';
import '../../dao/dao_system.dart';
import '../../entity/operating_hours.dart';
import '../../entity/system.dart';
import '../../util/date_time_ex.dart';
import '../../util/format.dart'; // For formatTime() or similar
import '../../util/local_date.dart';
import '../widgets/async_state.dart';
import '../widgets/circle.dart';
import '../widgets/surface.dart';
import 'job_event_ex.dart';
import 'schedule_helper.dart';

/// A single-month view of events
class MonthSchedule extends StatefulWidget with ScheduleHelper {
  const MonthSchedule(this.initialDate,
      {required this.onPageChange,
      required this.defaultJob,
      required this.monthKey,
      required this.showWeekends,
      super.key});

  final LocalDate initialDate;
  final int? defaultJob;
  final Future<LocalDate> Function(LocalDate targetDate) onPageChange;
  final GlobalKey<MonthViewState<JobEventEx>> monthKey;
  final bool showWeekends;

  @override
  State<MonthSchedule> createState() => _MonthScheduleState();
}

class _MonthScheduleState extends AsyncState<MonthSchedule, void> {
  late final EventController<JobEventEx> _monthController;
  CalendarEventData<JobEventEx>? _draggingEvent;

  late LocalDate currentDate;
  late bool showWeekends;
  late final System system;
  late final OperatingHours operatingHours;

  @override
  void initState() {
    super.initState();
    showWeekends = widget.showWeekends;
    _monthController = EventController();
  }

  @override
  Future<void> asyncInitState() async {
    system = await DaoSystem().get();
    operatingHours = system.getOperatingHours();
    currentDate = widget.initialDate;
    await _loadEventsForMonth();
  }

  @override
  void dispose() {
    _monthController.dispose();
    super.dispose();
  }

  Future<void> _loadEventsForMonth() async {
    final firstOfMonth = LocalDate(currentDate.year, currentDate.month);
    final firstOfNextMonth = LocalDate(currentDate.year, currentDate.month + 1);

    final dao = DaoJobEvent();
    final jobEvents =
        await dao.getEventsInRange(firstOfMonth, firstOfNextMonth);

    showWeekends = false;
    final eventData = <CalendarEventData<JobEventEx>>[];
    for (final jobEvent in jobEvents) {
      eventData.add((await JobEventEx.fromEvent(jobEvent)).eventData);
      if (jobEvent.start.isWeekEnd) {
        showWeekends = true;
      }
    }

    setState(() {
      _monthController
        ..clear()
        ..addAll(eventData);
    });
  }

  @override
  Widget build(BuildContext context) => CalendarControllerProvider<JobEventEx>(
        controller: _monthController,
        child: FutureBuilderEx(
            future: initialised,
            builder: (context, _) {
              /// Month View
              late final MonthView<JobEventEx> monthView;
              // ignore: join_return_with_assignment
              monthView = MonthView<JobEventEx>(
                showWeekends: showWeekends,
                // key: ValueKey(widget.initialDate),
                key: widget.monthKey,
                initialMonth: currentDate.toDateTime(),
                headerStyle: widget.headerStyle(),
                headerStringBuilder: widget.monthDateStringBuilder,
                onPageChange: (date, index) async => _onePageChange(date),
                cellBuilder:
                    (date, events, isToday, isInMonth, hideDaysNotInMonth) =>
                        _cellBuilder(monthView, date, events, isToday,
                            isInMonth, hideDaysNotInMonth),
                weekDayBuilder: (day) => Center(
                  child: Text(
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day],
                    style: const TextStyle(
                        color: Colors.white), // Weekday text color
                  ),
                ),
                onCellTap: (events, date) async {
                  /// [date] is always midnight so lets show a more reasonable
                  /// starting time for the event.
                  final openingTime =
                      operatingHours.openingTime(date.toLocalDate());
                  await widget.addEvent(
                      context, date.withTime(openingTime), widget.defaultJob);
                  await _loadEventsForMonth();
                },
                onEventTap: (event, date) async {
                  await widget.onEventTap(context, event);
                  await _loadEventsForMonth();
                },
              );
              return monthView;
            }),
      );

  Future<void> _onePageChange(DateTime date) async {
    final revisedDate = await widget.onPageChange(date.toLocalDate());

    currentDate = revisedDate;
    await _loadEventsForMonth();
  }

  /// Build month view cell.
  Widget _cellBuilder(
    MonthView<JobEventEx> monthView,
    DateTime date,
    List<CalendarEventData<JobEventEx>> events,
    bool isToday,
    bool isInMonth,
    bool hideDaysNotInMonth,
  ) {
    final backgroundColour = isToday
        ? SurfaceElevation.e4.color
        : isInMonth
            ? Colors.black
            : Colors.grey[350]!;

    final colour =
        isToday ? Colors.yellow : (isInMonth ? Colors.white : Colors.black);

    return DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColour, // Cell background
          border: Border.all(color: Colors.grey[700]!), // Optional cell border
        ),
        child: Column(
            children: _renderEvents(
                monthView, date, isToday, events, backgroundColour,
                color: colour)));
  }

  /// Render a list of event widgets
  List<Widget> _renderEvents(
      MonthView<JobEventEx> monthView,
      DateTime date,
      bool isToday,
      List<CalendarEventData<JobEventEx>> events,
      Color backgroundColour,
      {required Color color}) {
    final widgets = <Widget>[
      Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: isToday ? Colors.purpleAccent : color, // Text color
          ),
        ),
      )
    ];
    for (final event in events) {
      widgets.add(_renderEvent(monthView, event, backgroundColour));
    }
    return widgets;
  }

  /// build a single event widget.
  Widget _renderEvent(MonthView<JobEventEx> monthView,
      CalendarEventData<JobEventEx> event, Color backgroundColour) {
    var fontColor = Colors.white;
    if (widget.defaultJob == event.event!.job.id) {
      fontColor = Colors.orange;
    }
    return GestureDetector(
      onLongPressStart: (details) async {
        setState(() {
          _draggingEvent = event;
        });
        await _showDraggingAvatar(context, event, details.globalPosition);
      },
      onTap: () async {
        if (monthView.onEventTap != null) {
          monthView.onEventTap?.call(event, event.startTime!);
        }
      },
      child: Row(
        children: [
          Circle(
              color: event.event?.jobEvent.status.color ?? Colors.white,
              child: const Text('')),
          Text('${formatTime(event.startTime!, 'h:mm a').toLowerCase()} ',
              style: TextStyle(
                  color: fontColor, backgroundColor: backgroundColour)),
        ],
      ),
    );
  }

  Future<void> _showDraggingAvatar(BuildContext context,
      CalendarEventData<JobEventEx> event, Offset initialPosition) async {
    // Create an overlay entry for the drag avatar
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: initialPosition.dx,
        top: initialPosition.dy,
        child: Material(
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(8),
            color: event.color.withOpacity(0.8),
            child: Text(event.title),
          ),
        ),
      ),
    );

    // Insert the overlay entry
    Overlay.of(context).insert(overlayEntry);

    // Handle drag updates
    void onDragUpdate(DragUpdateDetails details) {
      overlayEntry?.markNeedsBuild();
    }

    // Handle drag end
    void onDragEnd(DraggableDetails details) {
      overlayEntry?.remove();
      overlayEntry = null;

      // Determine the drop target and update the event
      final dropDate = _determineDropDate(details.offset);
      if (dropDate != null) {
        _updateEventDate(event, dropDate);
      }

      setState(() {
        _draggingEvent = null;
      });
    }

    // Show the drag avatar and start listening for updates
    await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Draggable(
        feedback:
            const SizedBox.shrink(), // We are already showing a custom avatar
        onDragUpdate: onDragUpdate,
        onDragEnd: onDragEnd,
        child: const SizedBox.shrink(), // This child is not used, but required
      ),
    );
  }

  DateTime? _determineDropDate(Offset offset) {
    final monthView =
        widget.monthKey.currentContext?.findRenderObject() as RenderBox?;
    if (monthView == null) return null;

    final localOffset = monthView.globalToLocal(offset);
    final cellSize = monthView.size.width / 7; // Assuming 7 days a week
    final row = (localOffset.dy / cellSize).floor();
    final col = (localOffset.dx / cellSize).floor();

    // Calculate the new date based on the row and column
    // This is a simplified example and may need adjustments
    final initialDate = DateTime(currentDate.year, currentDate.month);
    final day = row * 7 + col - initialDate.weekday + 1;
    return DateTime(currentDate.year, currentDate.month, day);
  }

  void _updateEventDate(CalendarEventData<JobEventEx> event, DateTime newDate) {
    // Update the event's date in your data source
    // ...

    // Update the event in the EventController
    setState(() {
      _monthController.remove(event);
      final updatedEvent = event.copyWith(
        date: newDate,
        startTime: DateTime(newDate.year, newDate.month, newDate.day,
            event.startTime!.hour, event.startTime!.minute),
        endTime: DateTime(newDate.year, newDate.month, newDate.day,
            event.endTime!.hour, event.endTime!.minute),
      );
      _monthController.add(updatedEvent);
    });
  }
}
