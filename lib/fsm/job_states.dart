import 'package:fsm2/fsm2.dart';

import '../entity/job_status.dart';

/// --- fsm2 State types (1:1 with your JobStatus enum) ---
sealed class JobState extends State {
  const JobState({required this.visible, required this.status});
  // True if this [JobState] should be
  // shown as a potiential transition to a user.
  /// States with [visible] = false indicate states
  /// that are transitioned to via indirect actions
  /// such as Scheduling work.
  final bool visible;

  final JobStatus status;
}

// If you keep this, it can now be trivial:
JobStatus statusFromType(JobState s) => s.status;

Type stateTypeFromStatus(JobStatus s) =>
    _allStates.firstWhere((st) => st.status == s).runtimeType;

JobState stateFromType(Type t) => switch (t) {
  // const so we match on the Type rather than an instance of the
  const (Prospecting) => const Prospecting(),
  const (Quoting) => const Quoting(),
  const (AwaitingApproval) => const AwaitingApproval(),
  const (AwaitingPayment) => const AwaitingPayment(),
  const (ToBeScheduled) => const ToBeScheduled(),
  const (Scheduled) => const Scheduled(),
  const (InProgress) => const InProgress(),
  const (OnHold) => const OnHold(),
  const (AwaitingMaterials) => const AwaitingMaterials(),
  const (Completed) => const Completed(),
  const (ToBeBilled) => const ToBeBilled(),
  const (Rejected) => const Rejected(),
  _ => throw ArgumentError('Unknown JobState type: $t'),
};

/// Find the currently-active leaf state Type (simple non-nested machine).
Future<Type> currentState(StateMachine m) async {
  // We could also use stateOfMind, but this is explicit and reliable for a flat machine.
  if (await m.isInState<Prospecting>()) {
    return Prospecting;
  }
  if (await m.isInState<Quoting>()) {
    return Quoting;
  }
  if (await m.isInState<AwaitingApproval>()) {
    return AwaitingApproval;
  }
  if (await m.isInState<AwaitingPayment>()) {
    return AwaitingPayment;
  }
  if (await m.isInState<ToBeScheduled>()) {
    return ToBeScheduled;
  }
  if (await m.isInState<Scheduled>()) {
    return Scheduled;
  }
  if (await m.isInState<InProgress>()) {
    return InProgress;
  }
  if (await m.isInState<OnHold>()) {
    return OnHold;
  }
  if (await m.isInState<AwaitingMaterials>()) {
    return AwaitingMaterials;
  }
  if (await m.isInState<Completed>()) {
    return Completed;
  }
  if (await m.isInState<ToBeBilled>()) {
    return ToBeBilled;
  }
  if (await m.isInState<Rejected>()) {
    return Rejected;
  }
  throw StateError('Could not determine active state.');
}

const _allStates = <JobState>[
  Prospecting(),
  Quoting(),
  AwaitingApproval(),
  AwaitingPayment(),
  ToBeScheduled(),
  Scheduled(),
  InProgress(),
  OnHold(),
  AwaitingMaterials(),
  Completed(),
  ToBeBilled(),
  Rejected(),
];

// Leaf states — each sets its own visibility and status:
final class Prospecting extends JobState {
  const Prospecting() : super(visible: true, status: JobStatus.prospecting);
}

final class Quoting extends JobState {
  const Quoting() : super(visible: true, status: JobStatus.quoting);
}

final class AwaitingApproval extends JobState {
  const AwaitingApproval()
    : super(visible: true, status: JobStatus.awaitingApproval);
}

final class AwaitingPayment extends JobState {
  const AwaitingPayment()
    : super(visible: true, status: JobStatus.awaitingPayment);
}

final class ToBeScheduled extends JobState {
  const ToBeScheduled() : super(visible: true, status: JobStatus.toBeScheduled);
}

final class Scheduled extends JobState {
  const Scheduled() : super(visible: false, status: JobStatus.scheduled);
}

final class InProgress extends JobState {
  const InProgress() : super(visible: true, status: JobStatus.inProgress);
}

final class OnHold extends JobState {
  const OnHold() : super(visible: true, status: JobStatus.onHold);
}

final class AwaitingMaterials extends JobState {
  const AwaitingMaterials()
    : super(visible: true, status: JobStatus.awaitingMaterials);
}

final class Completed extends JobState {
  const Completed() : super(visible: true, status: JobStatus.completed);
}

final class ToBeBilled extends JobState {
  const ToBeBilled() : super(visible: true, status: JobStatus.toBeBilled);
}

final class Rejected extends JobState {
  const Rejected() : super(visible: true, status: JobStatus.rejected);
}
