import 'dart:async';

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../dao/dao_task.dart';
import '../dao/dao_time_entry.dart';
import '../entity/task.dart';
import '../entity/time_entry.dart';
import '../util/format.dart';
import 'time_entry_dialog.dart';

class HMBStartTimeEntry extends StatefulWidget {
  const HMBStartTimeEntry({
    required this.task,
    super.key,
  });

  final Task? task;

  @override
  State<StatefulWidget> createState() => HMBStartTimeEntryState();
}

class HMBStartTimeEntryState extends State<HMBStartTimeEntry> {
  Timer? _timer;
  late Future<TimeEntry?> _initialEntry;

  @override
  void initState() {
    super.initState();
    final completer = Completer<TimeEntry?>();
    _initialEntry = completer.future;
    // ignore: discarded_futures
    DaoTimeEntry().getActiveEntry().then((entry) {
      if (entry != null && entry.taskId == widget.task?.id) {
        completer.complete(entry);
      } else {
        completer.complete(null);
      }
      setState(() {
        _initTimer(entry);
        if (entry != null) {
          final task = widget.task;
          June.getState<TimeEntryState>(TimeEntryState.new)
              .setActiveTimeEntry(entry, task);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: _initialEntry,
      builder: (context, snapshot) {
        final timeEntry = snapshot.data;
        return Row(
          children: [
            IconButton(
              icon: Icon(timeEntry != null ? Icons.stop : Icons.play_arrow),
              onPressed: () async => _toggleTimer(timeEntry),
            ),
            _buildElapsedTime(timeEntry)
          ],
        );
      });

  Future<void> _toggleTimer(TimeEntry? timeEntry) async {
    final activeEntry = await DaoTimeEntry().getActiveEntry();
    DateTime? followOnStartTime;

    if (activeEntry != null && activeEntry.id != timeEntry?.id) {
      final otherTask = await DaoTask().getById(activeEntry.taskId);

      if (mounted) {
        final stoppedTimeEntry = await _showTimeEntryDialog(
            context, otherTask!, activeEntry,
            showTask: true);
        if (stoppedTimeEntry != null) {
          followOnStartTime =
              stoppedTimeEntry.endTime!.add(const Duration(minutes: 1));
          await DaoTimeEntry().update(stoppedTimeEntry);
        }
      }
    }

    if (mounted) {
      final newTimeEntry = await _showTimeEntryDialog(
          context, widget.task!, timeEntry,
          followOnStartTime: followOnStartTime);
      if (newTimeEntry != null) {
        if (timeEntry == null) {
          await DaoTimeEntry().insert(newTimeEntry);
          if (mounted) {
            setState(() {
              _startTimer(newTimeEntry);
            });
            June.getState<TimeEntryState>(TimeEntryState.new)
                .setActiveTimeEntry(newTimeEntry, widget.task);
          }
        } else {
          await DaoTimeEntry().update(newTimeEntry);
          if (mounted) {
            setState(_stopTimer);
            June.getState<TimeEntryState>(TimeEntryState.new)
                .clearActiveTimeEntry();
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
      setState(() {});
    });
  }

  void _stopTimer() {
    _timer?.cancel();
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

class TimeEntryState extends JuneState {
  TimeEntry? activeTimeEntry;
  Task? task;

  void setActiveTimeEntry(TimeEntry? entry, Task? task,
      {bool doRefresh = true}) {
    if (activeTimeEntry != entry) {
      activeTimeEntry = entry;
      this.task = task;
      if (doRefresh) {
        refresh();
      }
    }
  }

  void clearActiveTimeEntry() {
    activeTimeEntry = null;
    task = null;
    refresh();
  }
}
