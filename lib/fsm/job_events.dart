import 'package:fsm2/fsm2.dart';

import '../entity/entity.g.dart';

/// --- Events (user actions) ---
sealed class JobEvent extends Event {
  final Job job;
  JobEvent(this.job);

  /// Describe the action performed, rather than its destination status.
  String get label => switch (this) {
    StartQuoting() => 'Start quoting',
    SubmitQuote() => 'Mark quote sent',
    ApproveQuote() =>
      job.status == JobStatus.rejected ? 'Accept job' : 'Mark quote approved',
    PaymentReceived() => 'Confirm payment received',
    ScheduleJob() => 'Request scheduling',
    StartWork() => 'Start work',
    PauseJob() => 'Pause job',
    ResumeJob() => 'Resume work',
    MaterialsArrived() => 'Confirm materials arrived',
    CompleteJob() => 'Mark work complete',
    RaiseInvoice() => 'Mark for billing',
    RejectJob() => 'Reject job',
    ReopenJob() => 'Reopen job',
  };
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

class PaymentReceived extends JobEvent {
  PaymentReceived(super.job);
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

/// Resume work after completion; this does not undo earlier side effects.
class ReopenJob extends JobEvent {
  ReopenJob(super.job);
}

class RejectJob extends JobEvent {
  RejectJob(super.job);
}

/// Event factories so we can build real Event instances for guard
/// checking & firing.
final Map<Type, JobEvent Function(Job)> eventFactory = {
  StartQuoting: StartQuoting.new,
  SubmitQuote: SubmitQuote.new,
  ApproveQuote: ApproveQuote.new,
  PaymentReceived: PaymentReceived.new,
  ScheduleJob: ScheduleJob.new,
  StartWork: StartWork.new,
  PauseJob: PauseJob.new,
  ResumeJob: ResumeJob.new,
  MaterialsArrived: MaterialsArrived.new,
  CompleteJob: CompleteJob.new,
  RaiseInvoice: RaiseInvoice.new,
  RejectJob: RejectJob.new,
  ReopenJob: ReopenJob.new,
};

JobEvent createEvent<T extends JobEvent>(Job job, T eventType) =>
    switch (eventType) {
      StartQuoting() => StartQuoting(job),
      SubmitQuote() => SubmitQuote(job),
      ApproveQuote() => ApproveQuote(job),
      PaymentReceived() => PaymentReceived(job),
      ScheduleJob() => ScheduleJob(job),
      StartWork() => StartWork(job),
      PauseJob() => PauseJob(job),
      ResumeJob() => ResumeJob(job),
      MaterialsArrived() => MaterialsArrived(job),
      CompleteJob() => CompleteJob(job),
      RaiseInvoice() => RaiseInvoice(job),
      RejectJob() => RejectJob(job),
      ReopenJob() => ReopenJob(job),
    };
