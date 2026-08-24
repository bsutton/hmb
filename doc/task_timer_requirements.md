# Task Timer Requirements

## 1. Purpose

The task timer records work against a task while giving the user an immediate,
unambiguous indication that time is being recorded. Timer transitions must be
reliable across widget rebuilds, navigation, application lifecycle changes, and
switches between tasks or jobs.

## 2. Source of Truth and Invariants

1. An active timer is a `time_entry` row whose `end_time` is null.
2. At most one active time entry may exist across the application.
3. `ActiveTimeEntryState` mirrors the active database row and its task for UI
   notification. The database remains the recovery source of truth.
4. A task timer control shows Stop when its task owns the active entry and
   Start otherwise.
5. The global timer status bar is only rendered while an active entry exists.
   Its timer control is stop-only: it must always show Stop and must never
   initiate a timer.
6. The active timer's elapsed duration updates at least once per second.
   When a permitted start time is in the future, elapsed time displays zero
   until that start time is reached; it must never display a negative duration.
7. Only tasks in a timeable state may start. An awaiting-approval task requires
   explicit confirmation and is moved through the existing approval/start-work
   flow.

## 3. User-Visible States

| State | Task control | Global status bar |
| --- | --- | --- |
| No active timer | Start for each timeable task | Hidden |
| Timer active for this task | Stop plus elapsed time | Stop, elapsed time, task and job |
| Timer active for another task | Start; selecting it begins a switch | Stop for the active task |
| Start/stop persistence running | Initiating control disabled; blocking overlay shown | Existing state remains visible until persistence completes |
| Persistence failure | State is reconciled from the database; error is shown | Must reflect the reconciled active entry |

The words and icon semantics must agree. A control displaying "Tap to start
tracking time" must not show a Stop action, and a visible global status bar
must not show a Start action or the start message.

## 4. Start and Stop Flows

### 4.1 Start with no active timer

1. User taps Start.
2. If required, confirm that the task may be advanced to a timeable state.
3. Show the Start Timer dialog with the suggested start time.
4. On cancellation, leave the database and UI unchanged.
5. On confirmation, insert the active time entry, transition the job to active
   work, mark the task in progress, then publish the active entry.
6. Show Stop and the elapsed time on both the task and global status bar.

### 4.2 Stop the active timer

1. User taps Stop on either the task or global status bar.
2. Show the Stop Timer dialog with the suggested stop time.
3. On cancellation, keep the timer active and preserve all UI state.
4. On confirmation, persist `end_time`, clear the global active entry, stop the
   ticker, and hide the global status bar.

### 4.3 Switch tasks on the same job

1. User taps Start on a different task while another task is active.
2. Complete the Stop Timer flow for the prior task.
3. If stopping is cancelled, do not show the Start Timer dialog and keep the
   prior timer active.
4. If stopping succeeds, show the Start Timer dialog for the new task without
   depending on the initiating widget remaining mounted.
5. Suggest the new start time as one minute after the prior stop time so entries
   on the same job do not overlap.
6. If starting is cancelled, no timer remains active.
7. If starting succeeds, atomically replace the UI's active entry: the old task
   shows Start and the new task and global bar show Stop.

### 4.4 Switch tasks on different jobs

The interaction rules in section 4.3 apply. Under the existing billing rule,
the prior timer's suggested stop is rounded up to the next quarter hour and the
new timer's suggested start is rounded down to the current quarter hour. This
may intentionally overlap entries belonging to different jobs.

## 5. Lifecycle and Concurrency Requirements

1. A timer button accepts only one start/stop workflow at a time.
2. Dialog navigation must use a navigator that remains valid if DAO or global
   state notifications rebuild the originating task widget.
3. No asynchronous completion may access a disposed `State.context` or call
   `setState` on an unmounted state.
4. A rebuilt task timer must adopt a matching global active entry, start its
   ticker, and immediately render Stop.
5. A task losing ownership of the active entry must cancel its ticker and
   render Start.
6. Starting a ticker must cancel any prior ticker owned by that widget.
7. After an exception or an interrupted handoff, re-read the active entry from
   the database and republish it before reporting the failure.
8. Slow-action reporting must support repeated reports without reinitializing
   a final timer field, and must cancel its watchdog when the action ends.

## 6. Accessibility and Feedback

1. Start and Stop use a minimum 56 by 56 logical-pixel touch target and a
   32 logical-pixel icon.
2. Tooltips are explicit: `Start task timer` and `Stop task timer`.
3. Persistence uses the shared `BlockingUI` overlay with `Starting timer` or
   `Stopping timer` labels.
4. Failures are logged with a stack trace and displayed as an acknowledged
   error toast; failures must not be silent.

## 7. Acceptance Test Matrix

Each flow must verify the database-active entry, task control, global status
bar, elapsed ticker, and absence of Flutter exceptions.

| Scenario | Required assertions |
| --- | --- |
| Start and stop one task | Start dialog opens; confirmed start shows Stop in both locations; elapsed time advances; confirmed stop restores Start and hides the bar |
| Cancel a start | No active database row; task remains Start; bar remains hidden |
| Cancel a stop | Same entry remains active; Stop and elapsed time remain visible |
| Switch tasks on one job | Old entry is ended; new entry is active; old control is Start; new control and bar are Stop; same-job times do not overlap |
| Cancel first dialog during switch | Old timer remains active; no new entry is created |
| Cancel second dialog during switch | Old timer is ended; no timer is active; bar is hidden |
| Switch tasks across jobs | New task and bar show Stop; old task shows Start; suggested quarter-hour times follow section 4.4 |
| Rebuild/navigation while active | Returning to the screen immediately shows Stop and a running elapsed time |
| App restart with active entry | Startup restores the active entry; global bar is stop-only and identifies the correct task/job |
| Rapid repeated taps | Only one dialog/workflow and at most one active database row exist |
| Persistence failure | User sees an error; UI is reconciled to the database; no disposed-state exception occurs |

## 8. Automated Coverage

Automated tests should cover:

- repeated `BlockingUI` watchdog reports and cancellation;
- active-entry notification adoption and loss by task widgets;
- stop-only global status-bar semantics;
- start/stop cancellation and confirmation branches;
- same-job and cross-job suggested-time calculations;
- widget replacement during the stop-to-start handoff;
- the single-active-entry invariant at DAO/service level.

End-to-end fdb smoke tests should execute the acceptance paths against a
representative development database and capture `fdb describe`, screenshots,
and logs after every state transition.
