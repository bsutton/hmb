import 'package:fsm2/fsm2.dart';

import '../entity/job_status.dart';

/// --- fsm2 State types (1:1 with your JobStatus enum) ---
abstract class JobState extends State {}

class JobLifecycle extends JobState {}

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

JobStatus statusForStateType(Type t) {
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
