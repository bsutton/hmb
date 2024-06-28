import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../dao/dao_task.dart';
import '../dao/dao_time_entry.dart';
import '../entity/task.dart';
import '../entity/time_entry.dart';
import '../util/format.dart';
import 'time_entry_dialog.dart';

// final _dateTimeFormat = DateFormat('yyyy-MM-dd hh:mm a');

/// Display a control that lets you start/stop and time
/// entry as well as displaying the elapsed time.
class HMBStartTimeEntry extends StatefulWidget {
  const HMBStartTimeEntry({required this.task, super.key});
  @override
  State<StatefulWidget> createState() => HMBStartTimeEntryState();

  final Task? task;
}

class HMBStartTimeEntryState extends State<HMBStartTimeEntry> {
  Timer? _timer;
  late Future<TimeEntry?> _initialEntry;
  // TimeEntry? timeEntry;

  @override
  void initState() {
    super.initState();
    final completer = Completer<TimeEntry?>();
    _initialEntry = completer.future;
    // ignore: discarded_futures
    DaoTimeEntry().getActiveEntry().then((entry) {
      if (entry != null && entry.taskId == widget.task!.id) {
        completer.complete(entry);
      } else {
        completer.complete(null);
      }
      setState(() {
        // timeEntry = entry;
        _initTimer(entry);
      });
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
      future: _initialEntry,
      builder: (context, timeEntry) => Row(
            children: [
              IconButton(
                icon: Icon(timeEntry != null ? Icons.stop : Icons.play_arrow),
                onPressed: () async => _toggleTimer(timeEntry),
              ),
              _buildElapsedTime(timeEntry)
            ],
          ));

  Future<void> _toggleTimer(TimeEntry? timeEntry) async {
    final activeEntry = await DaoTimeEntry().getActiveEntry();

    /// If we stop an existing timer then the new one
    /// should start where the old one left off + 1 min.
    DateTime? followOnStartTime;

    /// If there is another activity running then it needs to be stopped.
    if (activeEntry != null && activeEntry.id != timeEntry?.id) {
      final otherTask = await DaoTask().getById(activeEntry.taskId);

      if (mounted) {
        /// There is an existing timer for another task,
        /// we must get the user to
        /// shut it down first.
        final stoppedTimeEntry = await _showTimeEntryDialog(
            context, otherTask!, activeEntry,
            showTask: true);
        if (stoppedTimeEntry != null) {
          followOnStartTime =
              stoppedTimeEntry.startTime.add(const Duration(minutes: 1));
          await DaoTimeEntry().update(stoppedTimeEntry);
        }
      }
    }

    if (mounted) {
      /// Ask the user to adjust the start or stop time.
      final newTimeEntry = await _showTimeEntryDialog(
          context, widget.task!, timeEntry,
          followOnStartTime: followOnStartTime);
      if (newTimeEntry != null) {
        /// The user selected a start or stop time.
        if (timeEntry == null) {
          // No existing entry so this is a new entry time.
          await DaoTimeEntry().insert(newTimeEntry);
          if (mounted) {
            setState(() {
              _startTimer(newTimeEntry);
            });
          }
        } else {
          /// There was an exising entry so this is a stop time.
          await DaoTimeEntry().update(newTimeEntry);
          if (mounted) {
            if (mounted) {
              setState(_stopTimer);
            }
          }
        }
      }
    }
  }

  void _initTimer(TimeEntry? timeEntry) {
    if (timeEntry != null) {
      _startTimer(timeEntry);
    }
  }

  void _startTimer(TimeEntry timeEntry) {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // this.timeEntry = timeEntry;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    // timeEntry = null;
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  Widget _buildElapsedTime(TimeEntry? timeEntry) {
    final running = timeEntry != null && timeEntry.endTime == null;
    if (running) {
      final elapsedTime = DateTime.now().difference(timeEntry.startTime);
      return Text('Elapsed: ${formatDuration(elapsedTime, seconds: true)}');
    } else {
      return const Text('Tap to start tracking time');
    }
  }

  Future<TimeEntry?> _showTimeEntryDialog(
          BuildContext context, Task task, TimeEntry? openEntry,
          {bool showTask = false, DateTime? followOnStartTime}) =>
      showDialog<TimeEntry>(
        context: context,
        builder: (context) => TimeEntryDialog(
            task: task,
            openEntry: openEntry,
            showTask: showTask,
            followOnStartTime: followOnStartTime),
      );
}
