import 'package:fsm2/fsm2.dart';

import '../entity/entity.g.dart';

/// --- fsm2 State types (1:1 with your JobStatus enum) ---
abstract class JobState extends State {}

class Prospecting extends JobState {}

class Quoting extends JobState {}

class AwaitingApproval extends JobState {}

class AwaitingPayment extends JobState {}

class ToBeScheduled extends JobState {}

class Scheduled extends JobState {}

class InProgress extends JobState {}

class OnHold extends JobState {}

class AwaitingMaterials extends JobState {}

class Completed extends JobState {}

class ToBeBilled extends JobState {}

class Rejected extends JobState {}

/// --- Events (user actions) ---
abstract class JobEvent extends Event {
  JobEvent(this.job);
  final Job job;
}

class StartQuoting extends JobEvent {
  StartQuoting(super.job);
}

class SubmitQuote extends JobEvent {
  SubmitQuote(super.job);
}

class ApproveQuote extends JobEvent {
  ApproveQuote(super.job);
}

class RecordDeposit extends JobEvent {
  RecordDeposit(super.job);
}

class ScheduleJob extends JobEvent {
  ScheduleJob(super.job);
}

class StartWork extends JobEvent {
  StartWork(super.job);
}

class PauseJob extends JobEvent {
  PauseJob(super.job);
}

class ResumeJob extends JobEvent {
  ResumeJob(super.job);
}

class MaterialsArrived extends JobEvent {
  MaterialsArrived(super.job);
}

class CompleteJob extends JobEvent {
  CompleteJob(super.job);
}

class RaiseInvoice extends JobEvent {
  RaiseInvoice(super.job);
}

class RejectJob extends JobEvent {
  RejectJob(super.job);
}

/// Helper: map between enum and fsm2 state Type.
Type _stateTypeFor(JobStatus s) {
  switch (s) {
    case JobStatus.prospecting:
      return Prospecting;
    case JobStatus.quoting:
      return Quoting;
    case JobStatus.awaitingApproval:
      return AwaitingApproval;
    case JobStatus.awaitingPayment:
      return AwaitingPayment;
    case JobStatus.toBeScheduled:
      return ToBeScheduled;
    case JobStatus.scheduled:
      return Scheduled;
    case JobStatus.inProgress:
      return InProgress;
    case JobStatus.onHold:
      return OnHold;
    case JobStatus.awaitingMaterials:
      return AwaitingMaterials;
    case JobStatus.completed:
      return Completed;
    case JobStatus.toBeBilled:
      return ToBeBilled;
    case JobStatus.rejected:
      return Rejected;
  }
}

JobStatus _statusForStateType(Type t) {
  if (t == Prospecting) {
    return JobStatus.prospecting;
  }
  if (t == Quoting) {
    return JobStatus.quoting;
  }
  if (t == AwaitingApproval) {
    return JobStatus.awaitingApproval;
  }
  if (t == AwaitingPayment) {
    return JobStatus.awaitingPayment;
  }
  if (t == ToBeScheduled) {
    return JobStatus.toBeScheduled;
  }
  if (t == Scheduled) {
    return JobStatus.scheduled;
  }
  if (t == InProgress) {
    return JobStatus.inProgress;
  }
  if (t == OnHold) {
    return JobStatus.onHold;
  }
  if (t == AwaitingMaterials) {
    return JobStatus.awaitingMaterials;
  }
  if (t == Completed) {
    return JobStatus.completed;
  }
  if (t == ToBeBilled) {
    return JobStatus.toBeBilled;
  }
  if (t == Rejected) {
    return JobStatus.rejected;
  }
  throw StateError('Unknown state type: $t');
}

/// Event factories so we can build real Event instances for guard checking & firing.
final Map<Type, JobEvent Function(Job)> _eventFactory = {
  StartQuoting: StartQuoting.new,
  SubmitQuote: SubmitQuote.new,
  ApproveQuote: ApproveQuote.new,
  RecordDeposit: RecordDeposit.new,
  ScheduleJob: ScheduleJob.new,
  StartWork: StartWork.new,
  PauseJob: PauseJob.new,
  ResumeJob: ResumeJob.new,
  MaterialsArrived: MaterialsArrived.new,
  CompleteJob: CompleteJob.new,
  RaiseInvoice: RaiseInvoice.new,
  RejectJob: RejectJob.new,
};

/// What the UI cares about: a target JobStatus to show, and a way to fire it.
class Next {
  const Next({required this.to, required this.fire});

  /// The target status the user would be moving to.
  final JobStatus to;

  /// Fire the underlying fsm2 event to do the transition.
  final Future<void> Function(StateMachine machine) fire;
}

/// Build the job FSM (wire transitions once).
Future<StateMachine> buildJobMachine() async {
  final machine = await StateMachine.create(
    (g) => g
      ..initialState<Prospecting>()
      ..state<Prospecting>((b) => b..on<StartQuoting, Quoting>())
      ..state<Quoting>(
        (b) => b
          ..on<SubmitQuote, AwaitingApproval>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<AwaitingApproval>(
        (b) => b
          ..on<ApproveQuote, AwaitingPayment>(
            sideEffect: (e) async => e.job.status = JobStatus.awaitingPayment,
          )
          ..on<ApproveQuote, ToBeScheduled>(
            sideEffect: (e) async => e.job.status == JobStatus.toBeScheduled,
          )
          ..on<RejectJob, Rejected>(),
      )
      ..state<AwaitingPayment>((b) => b..on<RecordDeposit, ToBeScheduled>())
      ..state<ToBeScheduled>((b) => b..on<ScheduleJob, Scheduled>())
      ..state<Scheduled>(
        (b) => b
          ..on<StartWork, InProgress>()
          ..on<PauseJob, OnHold>(),
      )
      ..state<InProgress>(
        (b) => b
          ..on<PauseJob, OnHold>()
          ..on<CompleteJob, Completed>(),
      )
      ..state<OnHold>(
        (b) => b
          ..on<ResumeJob, InProgress>()
          ..on<MaterialsArrived, AwaitingMaterials>(),
      )
      ..state<AwaitingMaterials>((b) => b..on<ResumeJob, InProgress>())
      ..state<Completed>((b) => b..on<RaiseInvoice, ToBeBilled>())
      ..state<ToBeBilled>((b) => b)
      ..state<Rejected>((b) => b),
  );

  return machine;
}

/// Find the currently-active leaf state Type (simple non-nested machine).
Future<Type> _activeLeafType(StateMachine m) async {
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

/// Return *guarded* next steps as JobStatus values + a way to trigger them.
///
/// How it works:
/// 1) We locate the active state's StateDefinition via `traverseTree()`.
/// 2) We list its transitions with `getTransitions(includeInherited: true)`.
/// 3) For each transition, we build the appropriate Event with your Job payload,
///    then ask `findTriggerableTransition(fromType, event)` to see if it would fire.
///    If yes, we include the mapped target JobStatus. :contentReference[oaicite:1]{index=1}
Future<List<Next>> nextFromFsm({
  required StateMachine machine,
  required Job job,
}) async {
  // Build a lookup of state type -> definition
  final defs = <Type, StateDefinition<State>>{};
  await machine.traverseTree(
    (sd, _) {
      defs[sd.stateType] = sd;
    },
  ); // debug helper; fine to use at runtime too. :contentReference[oaicite:2]{index=2}

  final activeType = await _activeLeafType(machine);
  final def = defs[activeType];
  if (def == null) {
    return const [];
  }

  final out = <Next>[];

  // All static (i.e., declared) transitions, including those inherited from parents.
  final transitions = def
      .getTransitions(); // :contentReference[oaicite:3]{index=3}

  for (final td in transitions) {
    // td.eventType and td.toState.stateType are available on TransitionDefinition.
    final factory = _eventFactory[td.triggerEvents.first];
    if (factory == null) {
      continue; // unknown or internal event
    }

    final event = factory(job);

    // Ask fsm2 if this event would actually trigger from the active state *right now*.
    final triggerable = await def.findTriggerableTransition(
      activeType,
      event,
    ); // :contentReference[oaicite:4]{index=4}
    if (triggerable == null) {
      continue;
    }

    final toType = triggerable.targetStates.first;
    final toStatus = _statusForStateType(toType);

    out.add(
      Next(
        to: toStatus,
        fire: (m) async => m.applyEvent(
          event,
        ), // fires the real transition. :contentReference[oaicite:5]{index=5}
      ),
    );
  }

  // Keep your original UI order, if you like.
  out.sort((a, b) => a.to.ordinal.compareTo(b.to.ordinal));
  return out;
}

/// Convenience for just the statuses (for your dropdown etc.)
Future<List<JobStatus>> nextStatusesOnly({
  required StateMachine machine,
  required Job job,
}) async {
  final next = await nextFromFsm(machine: machine, job: job);
  return next.map((n) => n.to).toList();
}
