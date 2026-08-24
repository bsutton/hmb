/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:june/june.dart';
import 'package:june/state_manager/src/simple/list_notifier.dart';
import 'package:material_ui/material_ui.dart';

import '../../dao/dao_task.dart';
import '../../dao/dao_time_entry.dart';
import '../../entity/job.dart';
import '../../entity/task.dart';
import '../../entity/task_status.dart';
import '../../entity/time_entry.dart';
import '../../fsm/job_events.dart';
import '../../fsm/job_status_fsm.dart';
import '../../util/dart/format.dart';
import '../../util/dart/log.dart';
import '../dialog/hmb_ask_user_to_continue.dart';
import '../dialog/start_timer_dialog.dart';
import '../dialog/stop_timer_dialog.dart';
import 'blocking_ui.dart';
import 'hmb_toast.dart';

class HMBStartTimeEntry extends StatefulWidget {
  final Task? task;
  final TimeEntry? activeTimeEntry;
  final bool stopOnly;
  @visibleForTesting
  final Future<TimeEntry?> Function()? loadActiveTimeEntry;
  final void Function(Job job, Task task) onStart;
  final VoidCallback? onTimerChanged;

  const HMBStartTimeEntry({
    required this.task,
    required this.onStart,
    this.activeTimeEntry,
    this.stopOnly = false,
    this.loadActiveTimeEntry,
    this.onTimerChanged,
    super.key,
  }) : assert(
         !stopOnly || activeTimeEntry != null,
         'A stop-only timer control requires an active time entry.',
       );

  @override
  State<StatefulWidget> createState() => HMBStartTimeEntryState();
}

class HMBStartTimeEntryState extends DeferredState<HMBStartTimeEntry> {
  static const _timerButtonSize = 56.0;
  static const _timerIconSize = 32.0;

  Timer? _timer;
  TimeEntry? timeEntry;
  var _timerActionInProgress = false;

  late Disposer disposer;

  @override
  void initState() {
    super.initState();
    timeEntry = widget.activeTimeEntry;
    if (timeEntry != null) {
      _startTimer(timeEntry!);
    }
    disposer = June.getState<ActiveTimeEntryState>(ActiveTimeEntryState.new)
        .addListener(() {
          final activeEntry = June.getState<ActiveTimeEntryState>(
            ActiveTimeEntryState.new,
          ).activeTimeEntry;
          final isThisTaskActive =
              activeEntry != null && activeEntry.taskId == widget.task?.id;
          var entryChanged = false;

          if (isThisTaskActive) {
            entryChanged = !_isSameTimeEntry(activeEntry, timeEntry);
            timeEntry = activeEntry;
            if (entryChanged || !(_timer?.isActive ?? false)) {
              _startTimer(activeEntry);
            }
          } else if (timeEntry != null) {
            // We are no longer the active timer.
            entryChanged = true;
            timeEntry = null;
            _timer?.cancel();
          }

          if (entryChanged && mounted) {
            setState(() {});
          }
        });
  }

  @override
  void didUpdateWidget(covariant HMBStartTimeEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activeEntry = widget.activeTimeEntry;
    if (widget.stopOnly &&
        !_isSameTimeEntry(activeEntry, oldWidget.activeTimeEntry)) {
      timeEntry = activeEntry;
      if (activeEntry == null) {
        _timer?.cancel();
      } else {
        _startTimer(activeEntry);
      }
    }
  }

  @override
  Future<void> asyncInitState() async {
    final entry =
        await (widget.loadActiveTimeEntry?.call() ??
            DaoTimeEntry().getActiveEntry());
    final task = widget.task;
    final isThisTaskActive = entry != null && entry.taskId == task?.id;

    if (isThisTaskActive) {
      timeEntry = entry;
    } else {
      timeEntry = null;
    }
    if (mounted) {
      setState(() {
        if (isThisTaskActive) {
          _initTimer(entry);
          final task = widget.task;
          June.getState<ActiveTimeEntryState>(
            ActiveTimeEntryState.new,
          ).setActiveTimeEntry(entry, task);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          JuneBuilder(
            ActiveTimeEntryState.new,
            builder: (timeEntryState) {
              final isActive =
                  widget.stopOnly ||
                  timeEntryState.activeTimeEntry?.taskId == widget.task?.id;

              return IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: _timerButtonSize,
                  height: _timerButtonSize,
                ),
                padding: const EdgeInsets.all(8),
                iconSize: _timerIconSize,
                tooltip: isActive ? 'Stop task timer' : 'Start task timer',
                // start / stop icon
                icon: Icon(
                  isActive ? Icons.stop : Icons.play_arrow,
                  color: isActive ? Colors.red : Colors.blue,
                ),
                onPressed: _timerActionInProgress ? null : _handleTimerPressed,
              );
            },
          ),
          _buildElapsedTime(timeEntry),
        ],
      ),
    ),
  );

  Future<void> _handleTimerPressed() async {
    final task = widget.task;
    if (_timerActionInProgress || (!widget.stopOnly && task == null)) {
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);

    setState(() => _timerActionInProgress = true);
    try {
      final activeEntry = June.getState<ActiveTimeEntryState>(
        ActiveTimeEntryState.new,
      ).activeTimeEntry;
      final isActiveTask = widget.stopOnly || activeEntry?.taskId == task?.id;
      if (isActiveTask) {
        await _stop(navigator);
      } else {
        if (task!.status.canBeTimed || await _confirmStartForUnapprovedTask()) {
          await _start(task, navigator);
        }
      }
    } catch (error, stackTrace) {
      await _syncActiveTimeEntryState();
      Log.e(
        'Unable to start or stop the task timer.',
        error: error,
        stackTrace: stackTrace,
      );
      HMBToast.error(
        'The task timer could not be updated. Please try again.',
        acknowledgmentRequired: true,
      );
    } finally {
      if (mounted) {
        setState(() => _timerActionInProgress = false);
      }
    }
  }

  Future<void> _stop(NavigatorState navigator) async {
    final runningTimer = await DaoTimeEntry().getActiveEntry();
    if (runningTimer == null) {
      await _syncActiveTimeEntryState();
      return;
    }
    final stopped = await _stopDialog(
      runningTimer,
      _roundUpToQuaterHour(DateTime.now()),
      navigator: navigator,
    );
    if (stopped != null && mounted) {
      widget.onTimerChanged?.call();
    }
  }

  Future<void> _start(Task task, NavigatorState navigator) async {
    final runningTimer = await DaoTimeEntry().getActiveEntry();

    Task? runningTask;
    if (runningTimer != null) {
      runningTask = await DaoTask().getById(runningTimer.taskId);
    }

    /// Fixed point in time for all calcs.
    /// Start of the current minute.
    final now = DateTime.now().copyWith(
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );

    final startStopTimes = await _determineStartStopTime(
      runningTimer: runningTimer,
      runningTask: runningTask,
      now: now,
      startTask: task,
    );

    var showStart = true;
    TimeEntry? stoppedEntry;

    /// If there is a running timer we need to stop it.
    /// as there can only be one active timer
    /// we have no more work to do but stop this time.
    if (runningTimer != null) {
      stoppedEntry = await _stopDialog(
        runningTimer,
        startStopTimes.priorTaskStopTime!,
        navigator: navigator,
        clearActiveState: false,
      );

      if (stoppedEntry == null) {
        showStart = false;
      } else {
        startStopTimes.applyStoppedEntry(
          stoppedEntry,
          sameJob: runningTask!.jobId == task.jobId,
        );
      }
    }

    if (showStart) {
      if (!navigator.mounted) {
        await _syncActiveTimeEntryState();
        return;
      }

      /// there is no other timer running so just start the new timer
      final started = await _startDialog(
        task,
        startStopTimes.startTime,
        navigator,
      );
      if (!started && stoppedEntry != null) {
        await _syncActiveTimeEntryState();
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<bool> _confirmStartForUnapprovedTask() async {
    final task = widget.task;
    if (task == null) {
      return false;
    }

    if (task.status == TaskStatus.awaitingApproval) {
      var confirmed = false;
      await askUserToContinue(
        context: context,
        title: 'Task Awaiting Approval',
        message:
            'This task is not currently approved.\n\nIf you continue, '
            'it will be automatically marked as approved and moved to '
            'In Progress, then the timer will start.',
        noLabel: 'Cancel',
        yesLabel: 'Start Timer',
        onConfirmed: () async {
          confirmed = true;
        },
      );
      return confirmed;
    }

    HMBToast.error(
      '''
The Task must be ${TaskStatus.approved.name} or ${TaskStatus.inProgress.name} in order to be timed''',
    );
    return false;
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

  Future<StopStartTime> _determineStartStopTime({
    required DateTime now,
    required Task? runningTask,
    required TimeEntry? runningTimer,
    required Task startTask,
  }) async {
    assert(
      (runningTask == null && runningTimer == null) ||
          (runningTask != null &&
              runningTimer != null &&
              runningTask.id == runningTimer.taskId),
      'The Timer must belong to the task or both be null',
    );

    final nowRoundedDown = now.copyWith(
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
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
          startTime: _roundDownToQuaterHour(now),
        );
      }

      /// Same job so we stop the current task time as 'now'
      /// and start the new timer as 'now' + 1 minute.
      // last second of the minute.
      return StopStartTime(
        priorTaskStopTime: nowRoundedDown,
        startTime: nowPlusOne,
      );
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
        final stopTime = priorEntry.endTime;
        final startTime = priorEntry.endTime!.add(const Duration(minutes: 1));
        return StopStartTime(priorTaskStopTime: stopTime, startTime: startTime);
      }
    }

    /// No timers running and no prior entries for the same job,
    /// in the last quarter hour
    return StopStartTime(
      priorTaskStopTime: null,
      startTime: _roundDownToQuaterHour(now),
    );
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

  Future<TimeEntry?> _stopDialog(
    TimeEntry activeEntry,
    DateTime stopTime, {
    required NavigatorState navigator,
    bool clearActiveState = true,
  }) async {
    final task = await DaoTask().getById(activeEntry.taskId);
    if (!navigator.mounted) {
      return null;
    }

    final stoppedTimeEntry = await StopTimerDialog.show(
      navigator.context,
      task: task!,
      timeEntry: activeEntry,
      showTask: true,
      stopTime: stopTime,
    );
    if (stoppedTimeEntry != null) {
      await BlockingUI().runAndWait(
        () => DaoTimeEntry().update(stoppedTimeEntry),
        label: 'Stopping timer',
      );

      if (mounted) {
        timeEntry = null;
      }
      if (clearActiveState) {
        June.getState<ActiveTimeEntryState>(
          ActiveTimeEntryState.new,
        ).clearActiveTimeEntry();
      }

      _timer?.cancel();
      if (mounted) {
        setState(() {});
      }
      return stoppedTimeEntry;
    }
    return null;
  }

  void _initTimer(TimeEntry? timeEntry) {
    if (timeEntry != null) {
      _startTimer(timeEntry);
    }
  }

  Future<bool> _startDialog(
    Task task,
    DateTime startTime,
    NavigatorState navigator,
  ) async {
    if (!navigator.mounted) {
      return false;
    }

    final newTimeEntry = await StartTimerDialog.show(
      navigator.context,
      task: task,
      startTime: startTime,
    );
    if (newTimeEntry == null) {
      return false;
    }

    final job = await BlockingUI().runAndWait(() async {
      await DaoTimeEntry().insert(newTimeEntry);

      /// If we are running a timer for a job then it must
      /// be the active job.
      final job = await transitionJobById(task.jobId, StartWork.new);

      // mark the task as in progress.
      task.status = TaskStatus.inProgress;
      await DaoTask().update(task);
      return job;
    }, label: 'Starting timer');

    if (mounted) {
      timeEntry = newTimeEntry;
    }
    June.getState<ActiveTimeEntryState>(
      ActiveTimeEntryState.new,
    ).setActiveTimeEntry(newTimeEntry, task);

    if (mounted) {
      _startTimer(newTimeEntry);
      widget.onStart(job, task);
      widget.onTimerChanged?.call();
    }
    return true;
  }

  Future<void> _syncActiveTimeEntryState() async {
    try {
      final activeEntry = await DaoTimeEntry().getActiveEntry();
      final activeState = June.getState<ActiveTimeEntryState>(
        ActiveTimeEntryState.new,
      );
      if (activeEntry == null) {
        activeState.clearActiveTimeEntry();
        return;
      }

      final activeTask = await DaoTask().getById(activeEntry.taskId);
      activeState.setActiveTimeEntry(activeEntry, activeTask);
    } catch (error, stackTrace) {
      Log.e(
        'Unable to refresh the active task timer.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _startTimer(TimeEntry timeEntry) {
    _timer?.cancel();
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

  bool _isSameTimeEntry(TimeEntry? left, TimeEntry? right) =>
      left != null && right != null && left.id == right.id;

  @override
  void dispose() {
    _timer?.cancel();
    disposer();
    super.dispose();
  }

  Widget _buildElapsedTime(TimeEntry? timeEntry) {
    final running = timeEntry != null && timeEntry.endTime == null;
    if (running) {
      final elapsedTime = runningTimerElapsed(
        startTime: timeEntry.startTime,
        now: DateTime.now(),
      );
      return Text(
        formatDuration(elapsedTime, seconds: true),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      return const Text(
        'Tap to start tracking time',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
  }
}

class ActiveTimeEntryState extends JuneState {
  TimeEntry? activeTimeEntry;
  Task? task;

  void setActiveTimeEntry(
    TimeEntry? entry,
    Task? task, {
    bool doRefresh = true,
  }) {
    activeTimeEntry = entry;
    this.task = task;
    if (doRefresh) {
      setState();
    }
  }

  void clearActiveTimeEntry() {
    activeTimeEntry = null;
    task = null;
    setState();
  }
}

class StopStartTime {
  DateTime startTime;
  DateTime? priorTaskStopTime;

  StopStartTime({required this.startTime, required this.priorTaskStopTime});

  void applyStoppedEntry(TimeEntry stoppedEntry, {required bool sameJob}) {
    if (sameJob) {
      startTime = stoppedEntry.endTime!.add(const Duration(minutes: 1));
    }
  }
}

Duration runningTimerElapsed({
  required DateTime startTime,
  required DateTime now,
}) {
  final difference = now.difference(startTime);
  return difference.isNegative ? Duration.zero : difference;
}
