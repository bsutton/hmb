import 'dart:async';

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../dao/dao_job.dart';
import '../../dao/dao_task.dart';
import '../../dao/dao_time_entry.dart';
import '../../entity/task.dart';
import '../../entity/time_entry.dart';
import '../../util/format.dart';
import '../dialog/start_timer_dialog.dart';
import '../dialog/stop_timer_dialog.dart';


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
        return GestureDetector(
          child: Row(
            children: [
              IconButton(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                visualDensity: const VisualDensity(horizontal: -4),
                icon: Icon(timeEntry != null ? Icons.stop : Icons.play_arrow),
                onPressed: () async => timeEntry != null
                    ? _stop(widget.task)
                    : _start(widget.task),
              ),
              _buildElapsedTime(timeEntry)
            ],
          ),
          onTap: () async =>
              timeEntry != null ? _stop(widget.task) : _start(widget.task),
        );
      });

  Future<void> _stop(Task? task) async {
    final runningTimer = await DaoTimeEntry().getActiveEntry();
    assert(runningTimer != null, 'there should be a running timer');
    await _stopDialog(runningTimer!, _roundUpToQuaterHour(DateTime.now()));
  }

  Future<void> _start(Task? task) async {
    final runningTimer = await DaoTimeEntry().getActiveEntry();

    Task? runningTask;
    if (runningTimer != null) {
      runningTask = await DaoTask().getById(runningTimer.taskId);
    }

    /// Fixed point in time for all calcs.
    /// Start of the current minute.
    final now =
        DateTime.now().copyWith(second: 0, millisecond: 0, microsecond: 0);

    final startStopTimes = await _determineStartStopTime(
        runningTimer: runningTimer,
        runningTask: runningTask,
        now: now,
        startTask: widget.task!);

    var showStart = true;

    /// If there is a running timer we need to stop it.
    /// as there can only be one active timer
    /// we have no more work to do but stop this time.
    if (runningTimer != null) {
      showStart =
          await _stopDialog(runningTimer, startStopTimes.priorTaskStopTime!);
    }

    if (showStart) {
      /// there is no other timer running so just start the new timer
      await _startDialog(widget.task!, startStopTimes.startTime);
    }
  }

  /// We are stopping a task, determine the stop time based on its
  /// relation to the start task.
  /// If its for the same job the stop time will be now.
  /// If its for a different job we round up to the nearest quarter hour.
  // DateTime _determineStopTime(
  //     {required DateTime now, required Task stopTask, Task? startTask}) {
  //   if (startTask != null && stopTask.jobId == startTask.jobId) {
  //     return now;
  //   }
  //   return _roundUpToQuaterHour(now);
  // }

  Future<StopStartTime> _determineStartStopTime(
      {required DateTime now,
      required Task? runningTask,
      required TimeEntry? runningTimer,
      required Task startTask}) async {
    assert(
        (runningTask == null && runningTimer == null) ||
            (runningTask != null &&
                runningTimer != null &&
                runningTask.id == runningTimer.taskId),
        'The Timer must belong to the task or both be null');

    final nowRoundedDown =
        now.copyWith(second: 0, millisecond: 0, microsecond: 0);
    final nowPlusOne = nowRoundedDown.add(const Duration(minutes: 1));

    if (runningTask != null) {
      if (runningTask.jobId != startTask.jobId) {
        /// different job so we round the stopping task up to the
        /// nearest 15 min and the starting task down to the nearest 15 min.
        /// So yes these jobs will overlap but they will normally be
        /// for two different clients (should we check this) and
        /// the billing rules are 15min or part there of - per job
        /// so this the correct calc given these rules.
        return StopStartTime(

            /// the stop time is probably wrong as the user
            /// forgot to stop the prior job.
            priorTaskStopTime: _roundUpToQuaterHour(now),
            startTime: _roundDownToQuaterHour(now));
      }

      /// Same job so we stop the current task time as 'now'
      /// and start the new timer as 'now' + 1 minute.
      // last second of the minute.
      return StopStartTime(
          priorTaskStopTime: nowRoundedDown, startTime: nowPlusOne);
    }

    /// As we have no running task Check for a prior time entry for
    /// the same job
    /// which may have been created by the  user manually stopping a timer
    /// or by the user starting a new timer and us automatically
    /// stopping an existing timer - toggle.
    /// if a timer (for the same job) was stopped in the last 15 minutes
    /// then we want to start the new timer seamlessly from the last one (plus 1
    /// minute)
    /// Note: if there is a running timer (for the same job) then
    /// it will show as running in the last quarter hour.
    final priorEntries = await DaoTimeEntry().getByJob(startTask.jobId);
    if (priorEntries.isNotEmpty) {
      final priorEntry = priorEntries.first;

      if (priorEntry.recentlyStopped(now)) {
        /// We should never see a running priorEntry as it would
        /// have been passed in as the [runningTask]
        /// So given there is a prior entry for the same job
        /// that has just been stopped we should start the new timer
        /// from the prior one (plus 1 minute) - we can't overlap
        /// tasks on the same job as the customer won't like this.
        final stopTime = priorEntry.endTime!;
        final startTime = priorEntry.endTime!.add(const Duration(minutes: 1));
        return StopStartTime(priorTaskStopTime: stopTime, startTime: startTime);
      }
    }

    /// No timers running and no prior entries for the same job,
    /// in the last quarter hour
    return StopStartTime(
        priorTaskStopTime: null, startTime: _roundDownToQuaterHour(now));
  }

  DateTime _roundUpToQuaterHour(DateTime now) => DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        ((now.minute ~/ 15) + 1) * 15,
      );

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

  Future<bool> _stopDialog(TimeEntry activeEntry, DateTime stopTime) async {
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
        return true;
      }
    }
    return false;
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

      /// If we are running a time for a job then it must
      /// be the active job.
      await DaoJob().markActive(task.jobId);
      _startTimer(newTimeEntry);
      June.getState<TimeEntryState>(TimeEntryState.new)
          .setActiveTimeEntry(newTimeEntry, widget.task);
    }
  }

  void _startTimer(TimeEntry timeEntry) {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      } else {
        /// there can be a race conditions when shutting down a
        /// timer so the check for [mounted] lets us clean up.
        _timer?.cancel();
      }
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
      return Text(formatDuration(elapsedTime, seconds: true));
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
  StopStartTime({required this.startTime, required this.priorTaskStopTime});

  DateTime startTime;
  DateTime? priorTaskStopTime;
}