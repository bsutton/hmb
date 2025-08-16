

import 'package:fsm2/fsm2.dart';

import '../entity/entity.g.dart';

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



/// Event factories so we can build real Event instances for guard checking & firing.
final Map<Type, JobEvent Function(Job)> eventFactory = {
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
