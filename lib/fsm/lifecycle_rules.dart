import '../entity/job_status.dart';
import '../entity/quote.dart';
import 'job_events.dart';
import 'quote_events.dart';

JobStatus? targetForJobEvent(JobStatus from, JobEvent event) => switch (from) {
  JobStatus.prospecting => switch (event) {
    StartQuoting() => JobStatus.quoting,
    SubmitQuote() => JobStatus.awaitingApproval,
    ProceedToScheduling() => JobStatus.toBeScheduled,
    StartWork() => JobStatus.inProgress,
    PauseJob() => JobStatus.onHold,
    RejectJob() => JobStatus.rejected,
    _ => null,
  },
  JobStatus.quoting => switch (event) {
    SubmitQuote() => JobStatus.awaitingApproval,
    ProceedToScheduling() => JobStatus.toBeScheduled,
    StartWork() => JobStatus.inProgress,
    PauseJob() => JobStatus.onHold,
    RejectJob() => JobStatus.rejected,
    _ => null,
  },
  JobStatus.awaitingApproval => switch (event) {
    ApproveQuote() => JobStatus.awaitingPayment,
    ProceedToScheduling() => JobStatus.toBeScheduled,
    StartWork() => JobStatus.inProgress,
    PauseJob() => JobStatus.onHold,
    RejectJob() => JobStatus.rejected,
    _ => null,
  },
  JobStatus.awaitingPayment => switch (event) {
    PaymentReceived() || ProceedToScheduling() => JobStatus.toBeScheduled,
    QuoteUnapproved() => JobStatus.awaitingApproval,
    StartWork() => JobStatus.inProgress,
    PauseJob() => JobStatus.onHold,
    RejectJob() => JobStatus.rejected,
    _ => null,
  },
  JobStatus.toBeScheduled => switch (event) {
    ScheduleJob() => JobStatus.scheduled,
    StartWork() => JobStatus.inProgress,
    PauseJob() => JobStatus.onHold,
    RejectJob() => JobStatus.rejected,
    _ => null,
  },
  JobStatus.scheduled => switch (event) {
    StartWork() => JobStatus.inProgress,
    WaitForMaterials() => JobStatus.awaitingMaterials,
    PauseJob() => JobStatus.onHold,
    RejectJob() => JobStatus.rejected,
    _ => null,
  },
  JobStatus.inProgress => switch (event) {
    StartWork() => JobStatus.inProgress,
    WaitForMaterials() => JobStatus.awaitingMaterials,
    PauseJob() => JobStatus.onHold,
    CompleteJob() => JobStatus.completed,
    RejectJob() => JobStatus.rejected,
    _ => null,
  },
  JobStatus.onHold => switch (event) {
    ResumeJob() => JobStatus.inProgress,
    WaitForMaterials() => JobStatus.awaitingMaterials,
    ProceedToScheduling() => JobStatus.toBeScheduled,
    RejectJob() => JobStatus.rejected,
    _ => null,
  },
  JobStatus.awaitingMaterials => switch (event) {
    MaterialsArrived() || ResumeJob() => JobStatus.inProgress,
    PauseJob() => JobStatus.onHold,
    RejectJob() => JobStatus.rejected,
    _ => null,
  },
  JobStatus.completed => switch (event) {
    ReopenWork() => JobStatus.inProgress,
    _ => null,
  },
  JobStatus.rejected => switch (event) {
    RestoreJob() => JobStatus.prospecting,
    _ => null,
  },
};

QuoteState? targetForQuoteEvent(QuoteState from, QuoteEvent event) =>
    switch (from) {
      QuoteState.reviewing => switch (event) {
        SendQuote() => QuoteState.sent,
        RejectQuoteEvent() => QuoteState.rejected,
        AmendQuote() => QuoteState.rejected,
        _ => null,
      },
      QuoteState.sent => switch (event) {
        SendQuote() => QuoteState.sent,
        ApproveQuoteEvent() => QuoteState.approved,
        RejectQuoteEvent() => QuoteState.rejected,
        WithdrawQuote() => QuoteState.withdrawn,
        AmendQuote() => QuoteState.rejected,
        _ => null,
      },
      QuoteState.approved => switch (event) {
        SendQuote() => QuoteState.approved,
        UnapproveQuote() => QuoteState.sent,
        QuoteInvoiced() => QuoteState.invoiced,
        RejectQuoteEvent() => QuoteState.rejected,
        AmendQuote() => QuoteState.rejected,
        _ => null,
      },
      QuoteState.invoiced => switch (event) {
        SendQuote() => QuoteState.invoiced,
        QuoteInvoiced() => QuoteState.invoiced,
        _ => null,
      },
      QuoteState.rejected || QuoteState.withdrawn => null,
    };
