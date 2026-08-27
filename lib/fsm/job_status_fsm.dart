import 'package:fsm2/fsm2.dart';

import '../dao/dao.g.dart';
import '../entity/entity.g.dart';
import 'job_events.dart';
import 'job_states.dart';
import 'lifecycle_event_dispatcher.dart';
import 'lifecycle_models.dart';
import 'lifecycle_rules.dart';

/// A user-facing domain action. Multiple actions may lead to the same state.
class Next {
  final JobStatus to;
  final LifecycleAction action;
  final Future<Job> Function() fire;

  const Next({required this.to, required this.action, required this.fire});
}

Future<Job> transitionJobById(int jobId, BuildEvent buildEvent) async =>
    (await LifecycleEventDispatcher().dispatchJob(
      jobId,
      buildEvent,
      context: LifecycleContext(source: 'application'),
    )).entity;

Future<Job> transitionJob(Job job, BuildEvent buildEvent) =>
    transitionJobById(job.id, buildEvent);

/// Navigation records recency only; opening a job must not start work.
Future<Job> markJobActive(int jobId) async {
  await DaoJob().markLastActive(jobId);
  return (await DaoJob().getById(jobId))!;
}

Future<Job> startJobQuoting(int jobId) async {
  final job = (await DaoJob().getById(jobId))!;
  if (job.status != JobStatus.prospecting) {
    await DaoJob().markLastActive(jobId);
    return (await DaoJob().getById(jobId))!;
  }
  return await transitionJobById(jobId, StartQuoting.new);
}

Future<Job> submitJobQuote(int jobId) =>
    transitionJobById(jobId, SubmitQuote.new);

Future<Job> rejectJob(int jobId) => transitionJobById(jobId, RejectJob.new);

/// Builds a side-effect-free fsm2 representation of the job workflow.
Future<StateMachine> buildJobMachine(Job job) =>
    StateMachine.create(production: true, (graph) {
      switch (job.status) {
        case JobStatus.prospecting:
          graph.initialState<Prospecting>();
        case JobStatus.quoting:
          graph.initialState<Quoting>();
        case JobStatus.awaitingApproval:
          graph.initialState<AwaitingApproval>();
        case JobStatus.awaitingPayment:
          graph.initialState<AwaitingPayment>();
        case JobStatus.toBeScheduled:
          graph.initialState<ToBeScheduled>();
        case JobStatus.scheduled:
          graph.initialState<Scheduled>();
        case JobStatus.inProgress:
          graph.initialState<InProgress>();
        case JobStatus.onHold:
          graph.initialState<OnHold>();
        case JobStatus.awaitingMaterials:
          graph.initialState<AwaitingMaterials>();
        case JobStatus.completed:
          graph.initialState<Completed>();
        case JobStatus.rejected:
          graph.initialState<Rejected>();
      }

      graph
        ..state<Prospecting>(
          (state) => state
            ..on<StartQuoting, Quoting>()
            ..on<SubmitQuote, AwaitingApproval>()
            ..on<ProceedToScheduling, ToBeScheduled>()
            ..on<StartWork, InProgress>()
            ..on<PauseJob, OnHold>()
            ..on<RejectJob, Rejected>(),
        )
        ..state<Quoting>(
          (state) => state
            ..on<SubmitQuote, AwaitingApproval>()
            ..on<ProceedToScheduling, ToBeScheduled>()
            ..on<StartWork, InProgress>()
            ..on<PauseJob, OnHold>()
            ..on<RejectJob, Rejected>(),
        )
        ..state<AwaitingApproval>(
          (state) => state
            ..on<ApproveQuote, AwaitingPayment>()
            ..on<ProceedToScheduling, ToBeScheduled>()
            ..on<StartWork, InProgress>()
            ..on<PauseJob, OnHold>()
            ..on<RejectJob, Rejected>(),
        )
        ..state<AwaitingPayment>(
          (state) => state
            ..on<PaymentReceived, ToBeScheduled>()
            ..on<ProceedToScheduling, ToBeScheduled>()
            ..on<QuoteUnapproved, AwaitingApproval>()
            ..on<StartWork, InProgress>()
            ..on<PauseJob, OnHold>()
            ..on<RejectJob, Rejected>(),
        )
        ..state<ToBeScheduled>(
          (state) => state
            ..on<ScheduleJob, Scheduled>()
            ..on<StartWork, InProgress>()
            ..on<PauseJob, OnHold>()
            ..on<RejectJob, Rejected>(),
        )
        ..state<Scheduled>(
          (state) => state
            ..on<StartWork, InProgress>()
            ..on<WaitForMaterials, AwaitingMaterials>()
            ..on<PauseJob, OnHold>()
            ..on<RejectJob, Rejected>(),
        )
        ..state<InProgress>(
          (state) => state
            ..on<StartWork, InProgress>()
            ..on<WaitForMaterials, AwaitingMaterials>()
            ..on<PauseJob, OnHold>()
            ..on<CompleteJob, Completed>()
            ..on<RejectJob, Rejected>(),
        )
        ..state<OnHold>(
          (state) => state
            ..on<ResumeJob, InProgress>()
            ..on<WaitForMaterials, AwaitingMaterials>()
            ..on<ProceedToScheduling, ToBeScheduled>()
            ..on<RejectJob, Rejected>(),
        )
        ..state<AwaitingMaterials>(
          (state) => state
            ..on<MaterialsArrived, InProgress>()
            ..on<ResumeJob, InProgress>()
            ..on<PauseJob, OnHold>()
            ..on<RejectJob, Rejected>(),
        )
        ..state<Completed>((state) => state..on<ReopenWork, InProgress>())
        ..state<Rejected>((state) => state..on<RestoreJob, Prospecting>());
    });

const _pickerActions = <LifecycleAction>[
  LifecycleAction(
    eventType: StartQuoting,
    label: 'Start quoting',
    hint: 'Begin preparing a quote',
  ),
  LifecycleAction(
    eventType: PaymentReceived,
    label: 'Payment received',
    hint: 'Record that the required payment was received',
  ),
  LifecycleAction(
    eventType: ProceedToScheduling,
    label: 'Proceed to scheduling',
    hint: 'Proceed without waiting for payment or a quote',
    requiresConfirmation: true,
  ),
  LifecycleAction(
    eventType: StartWork,
    label: 'Start work',
    hint: 'Record that work has begun',
    requiresConfirmation: true,
  ),
  LifecycleAction(
    eventType: PauseJob,
    label: 'Put on hold',
    hint: 'Pause the job',
  ),
  LifecycleAction(
    eventType: ResumeJob,
    label: 'Resume work',
    hint: 'Resume work on the job',
  ),
  LifecycleAction(
    eventType: WaitForMaterials,
    label: 'Wait for materials',
    hint: 'Pause work until materials arrive',
  ),
  LifecycleAction(
    eventType: MaterialsArrived,
    label: 'Materials arrived',
    hint: 'Resume work now that materials are available',
  ),
  LifecycleAction(
    eventType: CompleteJob,
    label: 'Complete job',
    hint: 'Mark work as complete',
    requiresConfirmation: true,
  ),
  LifecycleAction(
    eventType: ReopenWork,
    label: 'Reopen work',
    hint: 'Return the completed job to work in progress',
    requiresConfirmation: true,
  ),
  LifecycleAction(
    eventType: RejectJob,
    label: 'Reject job',
    hint: 'Reject the job and its active quotes',
    requiresConfirmation: true,
  ),
  LifecycleAction(
    eventType: RestoreJob,
    label: 'Restore job',
    hint: 'Restore the rejected job to prospecting',
    requiresConfirmation: true,
  ),
];

Future<List<Next>> nextFromFsm({
  required StateMachine machine,
  required Job job,
}) async {
  final next = <Next>[];
  for (final action in _pickerActions) {
    final factory = eventFactory[action.eventType]!;
    final event = factory(job);
    final target = targetForJobEvent(job.status, event);
    if (target == null) {
      continue;
    }
    next.add(
      Next(
        to: target,
        action: action,
        fire: () async => (await LifecycleEventDispatcher().dispatchJob(
          job.id,
          factory,
          context: LifecycleContext(source: 'job.statusPicker'),
        )).entity,
      ),
    );
  }
  return next;
}

Future<List<JobStatus>> nextStatusesOnly({
  required StateMachine machine,
  required Job job,
}) async => (await nextFromFsm(
  machine: machine,
  job: job,
)).map((next) => next.to).toList();
