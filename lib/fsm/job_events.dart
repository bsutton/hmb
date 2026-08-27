import 'package:fsm2/fsm2.dart';

import '../entity/job.dart';
import '../entity/task.dart';
import '../entity/time_entry.dart';

/// A domain action which may move a job through its lifecycle.
sealed class JobEvent extends Event {
  final Job job;

  JobEvent(this.job);

  String get name;
}

class StartQuoting extends JobEvent {
  StartQuoting(super.job);
  @override
  String get name => 'StartQuoting';
}

class SubmitQuote extends JobEvent {
  SubmitQuote(super.job);
  @override
  String get name => 'QuoteSubmitted';
}

class ApproveQuote extends JobEvent {
  ApproveQuote(super.job);
  @override
  String get name => 'QuoteApproved';
}

class QuoteUnapproved extends JobEvent {
  QuoteUnapproved(super.job);
  @override
  String get name => 'QuoteUnapproved';
}

class QuoteNeedsRevision extends JobEvent {
  QuoteNeedsRevision(super.job);
  @override
  String get name => 'QuoteNeedsRevision';
}

class PaymentReceived extends JobEvent {
  PaymentReceived(super.job);
  @override
  String get name => 'PaymentReceived';
}

class ProceedToScheduling extends JobEvent {
  ProceedToScheduling(super.job);
  @override
  String get name => 'ProceedToScheduling';
}

class ScheduleJob extends JobEvent {
  ScheduleJob(super.job);
  @override
  String get name => 'ScheduleCreated';
}

class ScheduleRemoved extends JobEvent {
  ScheduleRemoved(super.job);
  @override
  String get name => 'ScheduleRemoved';
}

class StartWork extends JobEvent {
  final Task? task;
  final TimeEntry? timeEntry;

  StartWork(super.job, {this.task, this.timeEntry});
  @override
  String get name => 'StartWork';
}

class PauseJob extends JobEvent {
  PauseJob(super.job);
  @override
  String get name => 'Hold';
}

class ResumeJob extends JobEvent {
  ResumeJob(super.job);
  @override
  String get name => 'Resume';
}

class WaitForMaterials extends JobEvent {
  WaitForMaterials(super.job);
  @override
  String get name => 'WaitForMaterials';
}

class MaterialsArrived extends JobEvent {
  MaterialsArrived(super.job);
  @override
  String get name => 'MaterialsArrived';
}

class CompleteJob extends JobEvent {
  CompleteJob(super.job);
  @override
  String get name => 'CompleteJob';
}

class ReopenWork extends JobEvent {
  ReopenWork(super.job);
  @override
  String get name => 'ReopenWork';
}

class ReopenForScheduling extends JobEvent {
  ReopenForScheduling(super.job);
  @override
  String get name => 'ReopenForScheduling';
}

class RejectJob extends JobEvent {
  RejectJob(super.job);
  @override
  String get name => 'RejectJob';
}

class RestoreJob extends JobEvent {
  RestoreJob(super.job);
  @override
  String get name => 'RestoreJob';
}

typedef BuildEvent = JobEvent Function(Job job);

final Map<Type, BuildEvent> eventFactory = {
  StartQuoting: StartQuoting.new,
  SubmitQuote: SubmitQuote.new,
  ApproveQuote: ApproveQuote.new,
  QuoteUnapproved: QuoteUnapproved.new,
  QuoteNeedsRevision: QuoteNeedsRevision.new,
  PaymentReceived: PaymentReceived.new,
  ProceedToScheduling: ProceedToScheduling.new,
  ScheduleJob: ScheduleJob.new,
  ScheduleRemoved: ScheduleRemoved.new,
  StartWork: StartWork.new,
  PauseJob: PauseJob.new,
  ResumeJob: ResumeJob.new,
  WaitForMaterials: WaitForMaterials.new,
  MaterialsArrived: MaterialsArrived.new,
  CompleteJob: CompleteJob.new,
  ReopenWork: ReopenWork.new,
  ReopenForScheduling: ReopenForScheduling.new,
  RejectJob: RejectJob.new,
  RestoreJob: RestoreJob.new,
};
