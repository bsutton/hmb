import 'dart:async';

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../dao/dao_job.dart';
import '../dao/dao_task.dart';
import '../dao/dao_time_entry.dart';
import '../entity/task.dart';
import '../entity/time_entry.dart';
import '../util/format.dart';
import 'start_timer_dialog.dart';
import 'stop_timer_dialog.dart';

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
      if (mounted) {
        setState(() {
          _initTimer(entry);
          if (entry != null) {
            final task = widget.task;
            June.getState<TimeEntryState>(TimeEntryState.new)
                .setActiveTimeEntry(entry, task);
          }
        });
      }
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
              onPressed: () async =>
                  timeEntry != null ? _stop(widget.task) : _start(widget.task),
            ),
            _buildElapsedTime(timeEntry)
          ],
        );
      });

  Future<void> _stop(Task? task) async {
    final runningTimer = await DaoTimeEntry().getActiveEntry();
    assert(runningTimer != null, 'there should be a running timer');
    await _stopDialog(runningTimer!, _roundUpToQuaterHour(DateTime.now()));
  }

  Future<void> _start(Task? task) async {
    final runningTimer = await DaoTimeEntry().getActiveEntry();

    Task? stopTask;
    if (runningTimer != null) {
      stopTask = await DaoTask().getById(runningTimer.taskId);
    }

    /// Fixed point in time for all cals.
    final now = DateTime.now();

    final startStopTimes = await _determineStartStopTime(
        now: now, stopTask: stopTask, startTask: widget.task!);

    /// as there can only be one active timer
    /// we have no more work to do but stop this time.
    if (runningTimer != null) {
      await _stopDialog(runningTimer, startStopTimes.stopTime!);
    }

    /// there is no other timer running so just start the new timer
    await _startDialog(widget.task!, startStopTimes.startTime);
  }

  /// We are stopping a task, determine the stop time based on its
  /// relation to the start task.
  /// If its for the same job the stop time will be now.
  /// If its for a different job we round up to the nearest quarter hour.
  DateTime _determineStopTime(
      {required DateTime now, required Task stopTask, Task? startTask}) {
    if (startTask != null && stopTask.jobId == startTask.jobId) {
      return now;
    }
    return _roundUpToQuaterHour(now);
  }

  Future<StopStartTime> _determineStartStopTime(
      {required DateTime now,
      required Task? stopTask,
      required Task startTask}) async {
    DateTime? stopTime;
    DateTime startTime;

    final stopJob = await DaoJob().getById(stopTask?.jobId);
    final startJob = await DaoJob().getById(startTask.jobId);

    if (startJob?.id != stopJob?.id) {
      return StopStartTime(

          /// probably wrong as the user forgot to stop the prior job.
          stopTime: _roundUpToQuaterHour(now),
          startTime: _roundDownToQuaterHour(now));
    }

    /// Check for a prior time entry for the same job
    /// which may have been created by the  user manually stopping a timer
    /// or by the user starting a new timer and us automatically
    /// stopping an existing timer - toggle.
    /// if a timer (for the same job) was stopped in the last 15 minutes
    /// then we want to start the new time seamlessly from the last one (plus 1
    /// minute)
    /// Note: if there is a running timer (for the same job) then
    /// it will show as running the last quarter hour.
    final priorEntries = await DaoTimeEntry().getByJob(startTask.jobId);
    if (priorEntries.isNotEmpty) {
      final priorEntry = priorEntries.last;

      if (priorEntry.inLastQuarterHour(now)) {
        stopTime = priorEntry.endTime ?? now;
        startTime = stopTime.add(const Duration(minutes: 1));
        return StopStartTime(stopTime: stopTime, startTime: startTime);
      }
    }

    /// No prior entries for the same job, in the last quarter hour
    return StopStartTime(
        stopTime: stopTime, startTime: _roundDownToQuaterHour(now));
  }

  DateTime _roundUpToQuaterHour(DateTime now) => DateTime(
      now.year, now.month, now.day, now.hour, ((now.minute ~/ 15) + 1) * 15);

  DateTime _roundDownToQuaterHour(DateTime now) =>
      DateTime(now.year, now.month, now.day, now.hour, (now.minute ~/ 15) * 15);

  //   void calcNearest() {
  //   final now = DateTime.now();
  //   DateTime nearestQuarterHour;

  //   if (widget.openEntry == null) {
  //     /// start time
  //     nearestQuarterHour = widget.followOnStartTime ??
  //         DateTime(now.year, now.month, now.day, now.hour,
  //             (now.minute ~/ 15) * 15);
  //   } else {
  //     // end time
  //     if (widget.followOnStartTime != null) {
  //       /// the timer is being stoped becuase a new timer is being started
  //       /// so no rounding
  //       nearestQuarterHour =
  //           widget.followOnStartTime!.subtract(const Duration(minutes: 1));
  //     } else {
  //       nearestQuarterHour = DateTime(now.year, now.month, now.day, now.hour,
  //           ((now.minute ~/ 15) + 1) * 15);
  //     }
  //   }
  // }

  Future<void> _stopDialog(TimeEntry activeEntry, DateTime stopTime) async {
    final task = await DaoTask().getById(activeEntry.taskId);

    if (mounted) {
      final stoppedTimeEntry = await StopTimerDialog.show(context,
          task: task!,
          timeEntry: activeEntry,
          showTask: true,
          stopTime: stopTime);
      if (stoppedTimeEntry != null) {
        stoppedTimeEntry.endTime!.add(const Duration(minutes: 1));
        await DaoTimeEntry().update(stoppedTimeEntry);
        June.getState<TimeEntryState>(TimeEntryState.new)
            .clearActiveTimeEntry();

        _timer?.cancel();
        setState(() {});
      }
    }
  }

  void _initTimer(TimeEntry? timeEntry) {
    if (timeEntry != null) {
      _startTimer(timeEntry);
    }
  }

  Future<void> _startDialog(Task task, DateTime startTime) async {
    final newTimeEntry = await StartTimerDialog.show(context,
        task: widget.task!, startTime: startTime);
    if (newTimeEntry != null) {
      await DaoTimeEntry().insert(newTimeEntry);
      _startTimer(newTimeEntry);
      June.getState<TimeEntryState>(TimeEntryState.new)
          .setActiveTimeEntry(newTimeEntry, widget.task);
    }
  }

  void _startTimer(TimeEntry timeEntry) {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
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

class StopStartTime {
  StopStartTime({required this.startTime, required this.stopTime});

  DateTime startTime;
  DateTime? stopTime;
}
