import 'package:fsm2/fsm2.dart';

import '../dao/dao.g.dart';
import '../entity/entity.g.dart';
import 'job_events.dart';
import 'job_states.dart';

/// What the UI cares about: a target JobStatus to show, and a way to fire it.
class Next {
  /// The target status the user would be moving to.
  final JobStatus to;

  /// Fire the underlying fsm2 event to do the transition.
  final Future<void> Function(StateMachine machine) fire;

  const Next({required this.to, required this.fire});
}

typedef BuildEvent = JobEvent Function(Job job);

/// Transitions the [Job] and then returns the updated [Job]
Future<Job> transitionJobById(int jobid, BuildEvent buildEvent) async {
  final job = await DaoJob().getById(jobid);
  final event = buildEvent(job!);
  final machine = await buildJobMachine(job);

  machine.applyEvent(event);

  return (await DaoJob().getById(jobid))!;
}

/// Transitions the [Job] and then returns the updated [Job]
Future<Job> transitionJob(Job job, BuildEvent buildEvent) async {
  final machine = await buildJobMachine(job);
  final event = buildEvent(job);
  machine.applyEvent(event);
  return (await DaoJob().getById(job.id))!;
}

/// Build the job FSM (wire transitions once).

Future<StateMachine> buildJobMachine(Job job) async {
  final machine = await StateMachine.create(production: true, (g) {
    // Hydrate the state from the job
    switch (job.status) {
      case JobStatus.prospecting:
        g.initialState<Prospecting>();
      case JobStatus.quoting:
        g.initialState<Quoting>();
      case JobStatus.awaitingApproval:
        g.initialState<AwaitingApproval>();
      case JobStatus.awaitingPayment:
        g.initialState<AwaitingPayment>();
      case JobStatus.toBeScheduled:
        g.initialState<ToBeScheduled>();
      case JobStatus.scheduled:
        g.initialState<Scheduled>();
      case JobStatus.inProgress:
        g.initialState<InProgress>();
      case JobStatus.onHold:
        g.initialState<OnHold>();
      case JobStatus.awaitingMaterials:
        g.initialState<AwaitingMaterials>();
      case JobStatus.completed:
        g.initialState<Completed>();
      case JobStatus.toBeBilled:
        g.initialState<ToBeBilled>();
      case JobStatus.rejected:
        g.initialState<Rejected>();
    }

    // Super/parent state via nesting
    g
      // children (inherit RejectJob → Rejected)
      ..state<Prospecting>(
        (b) => b
          ..on<StartQuoting, Quoting>()
          ..on<PaymentReceived, ToBeScheduled>()
          ..on<StartWork, InProgress>()
          ..on<PauseJob, OnHold>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<Quoting>(
        (b) => b
          ..onEnter((_, _) => _updateJobStatus(job, JobStatus.quoting))
          ..on<SubmitQuote, AwaitingApproval>()
          ..on<StartWork, InProgress>()
          ..on<PauseJob, OnHold>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<AwaitingApproval>(
        (b) => b
          ..onEnter((_, _) => _updateJobStatus(job, JobStatus.awaitingApproval))
          ..on<ApproveQuote, AwaitingPayment>()
          ..on<PauseJob, OnHold>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<AwaitingPayment>(
        (b) => b
          ..onEnter((_, _) => _updateJobStatus(job, JobStatus.awaitingPayment))
          ..on<PaymentReceived, ToBeScheduled>()
          ..on<StartWork, InProgress>()
          ..on<ScheduleJob, Scheduled>()
          ..on<PauseJob, OnHold>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<ToBeScheduled>(
        (b) => b
          ..onEnter((_, _) async {
            await _approveTasks(job);
          })
          ..on<ScheduleJob, Scheduled>()
          ..on<StartWork, InProgress>()
          ..on<PauseJob, OnHold>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<Scheduled>(
        (b) => b
          ..onEnter((_, _) async {
            await DaoJob().markScheduled(job);
            await _approveTasks(job);
          })
          ..on<StartWork, InProgress>()
          ..on<PauseJob, OnHold>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<InProgress>(
        (b) => b
          ..onEnter((_, _) => _inProgress(job))
          ..on<StartWork, InProgress>()
          ..on<CompleteJob, Completed>()
          ..on<PauseJob, OnHold>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<OnHold>(
        (b) => b
          ..on<ResumeJob, InProgress>()
          ..on<MaterialsArrived, InProgress>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<AwaitingMaterials>(
        (b) => b
          ..on<ResumeJob, InProgress>()
          ..on<PauseJob, OnHold>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<Completed>(
        (b) => b
          ..on<RaiseInvoice, ToBeBilled>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<ToBeBilled>((b) => b..on<CompleteJob, Completed>())
      // terminal-ish state sits outside; not rejectable itself
      ..state<Rejected>(
        (b) => b
          ..on<ApproveQuote, AwaitingPayment>(
            sideEffect: (e) =>
                _updateJobStatus(e.job, JobStatus.awaitingApproval),
          ), // e.g., “unreject” flow if you want it
      );
  });

  return machine;
}

Future<void> _inProgress(Job job) async {
  await DaoJob().markActive(job.id);
  await _updateJobStatus(job, JobStatus.inProgress);
  await _approveTasks(job);
}

Future<void> _approveTasks(Job job) async {
  final daoTask = DaoTask();
  final tasks = await daoTask.getTasksByJob(job.id);

  for (final task in tasks) {
    await daoTask.jobHasBeenApproved(task);
  }
}

Future<void> _updateJobStatus(Job job, JobStatus status) async {
  job.status = status;

  await DaoJob().update(job);
}

/// Return *guarded* next steps as JobStatus values + a way to trigger them.
///
/// How it works:
/// 1) We locate the active state's StateDefinition via `traverseTree()`.
/// 2) We list its transitions with `getTransitions(includeInherited: true)`.
/// 3) For each transition, we build the appropriate Event with your
/// Job payload,
///    then ask `findTriggerableTransition(fromType, event)` to see if
/// it would fire.
///    If yes, we include the mapped target JobStatus. :contentReference
/// [oaicite:1]
/// {index=1}
Future<List<Next>> nextFromFsm({
  required StateMachine machine,
  required Job job,
}) async {
  // Build a lookup of state type -> definition
  final defs = <Type, StateDefinition<State>>{};
  await machine.traverseTree((sd, _) {
    defs[sd.stateType] = sd;
  });

  final activeType = await currentState(machine);
  final def = defs[activeType];
  if (def == null) {
    return const [];
  }

  final out = <Next>[];

  // All static (i.e., declared) transitions, including those
  //inherited from parents.
  final transitions = def
      .getTransitions(); // :contentReference[oaicite:3]{index=3}

  for (final td in transitions) {
    // td.eventType and td.toState.stateType are available on
    // TransitionDefinition.
    final factory = eventFactory[td.triggerEvents.first];
    if (factory == null) {
      continue; // unknown or internal event
    }

    final event = factory(job);

    // Ask fsm2 if this event would actually trigger from the active
    //state *right now*.
    final triggerable = await def.findTriggerableTransition(
      activeType,
      event,
    ); // :contentReference[oaicite:4]{index=4}
    if (triggerable == null) {
      continue;
    }

    final toType = stateFromType(triggerable.targetStates.first);

    if (!toType.visible) {
      continue;
    }
    final toStatus = statusFromType(toType);

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
