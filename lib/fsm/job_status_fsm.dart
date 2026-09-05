import 'package:fsm2/fsm2.dart';

import '../dao/dao.g.dart';
import '../entity/entity.g.dart';
import 'job_events.dart';
import 'job_states.dart';

/// An available action, its resulting status, and a way to perform it.
class Next {
  final JobEvent event;

  String get label => event.label;

  /// The target status the user would be moving to.
  final JobStatus to;

  /// Fire the underlying fsm2 event to do the transition.
  final Future<void> Function(StateMachine machine) fire;

  const Next({required this.event, required this.to, required this.fire});
}

typedef BuildEvent = JobEvent Function(Job job);

/// Transitions the [Job] and then returns the updated [Job]
Future<Job> transitionJobById(int jobid, BuildEvent buildEvent) async {
  final job = await DaoJob().getById(jobid);
  final event = buildEvent(job!);
  final machine = await buildJobMachine(job);

  machine.applyEvent(event);
  await machine.complete;

  return (await DaoJob().getById(jobid))!;
}

/// Transitions the [Job] and then returns the updated [Job]
Future<Job> transitionJob(Job job, BuildEvent buildEvent) async {
  final machine = await buildJobMachine(job);
  final event = buildEvent(job);
  machine.applyEvent(event);
  await machine.complete;
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
            await _updateJobStatus(job, JobStatus.toBeScheduled);
            await _ensureScheduleTodo(job);
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
          ..on<CompleteJob, Completed>()
          ..on<PauseJob, OnHold>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<OnHold>(
        (b) => b
          ..onEnter((_, _) => _updateJobStatus(job, JobStatus.onHold))
          ..on<ResumeJob, InProgress>()
          ..on<ScheduleJob, ToBeScheduled>()
          ..on<MaterialsArrived, InProgress>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<AwaitingMaterials>(
        (b) => b
          ..onEnter(
            (_, _) => _updateJobStatus(job, JobStatus.awaitingMaterials),
          )
          ..on<ResumeJob, InProgress>()
          ..on<PauseJob, OnHold>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<Completed>(
        (b) => b
          ..onEnter((_, _) => _updateJobStatus(job, JobStatus.completed))
          ..on<ReopenJob, InProgress>()
          ..on<RaiseInvoice, ToBeBilled>()
          ..on<RejectJob, Rejected>(),
      )
      ..state<ToBeBilled>(
        (b) => b
          ..onEnter((_, _) => _updateJobStatus(job, JobStatus.toBeBilled))
          ..on<CompleteJob, Completed>()
          ..on<ReopenJob, InProgress>(),
      )
      ..state<Rejected>(
        (b) => b
          ..onEnter((_, _) => _updateJobStatus(job, JobStatus.rejected))
          ..on<ApproveQuote, AwaitingPayment>(),
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

Future<void> _ensureScheduleTodo(Job job) async {
  final openTodos = await DaoToDo().getOpenByJob(job.id);
  final alreadyExists = openTodos.any(
    (todo) => todo.title.trim().toLowerCase() == 'schedule job',
  );
  if (alreadyExists) {
    return;
  }

  await DaoToDo().insert(
    ToDo.forInsert(
      title: 'Schedule job',
      parentType: ToDoParentType.job,
      parentId: job.id,
      priority: ToDoPriority.high,
    ),
  );
}

/// Return permitted user actions, preserving events with the same destination.
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
  final seenEvents = <Type>{};

  // All static (i.e., declared) transitions, including those
  //inherited from parents.
  final transitions = def.getTransitions();

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
    final triggerable = await def.findTriggerableTransition(activeType, event);
    if (triggerable == null) {
      continue;
    }

    final toType = stateFromType(triggerable.targetStates.first);

    if (!toType.visible) {
      continue;
    }
    final toStatus = statusFromType(toType);
    if (toStatus == statusFromType(stateFromType(activeType)) ||
        !seenEvents.add(event.runtimeType)) {
      continue;
    }

    out.add(
      Next(
        event: event,
        to: toStatus,
        fire: (m) async {
          m.applyEvent(event);
          await m.complete;
        },
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
  return next.map((n) => n.to).toSet().toList();
}
