import 'package:fsm2/fsm2.dart';

import '../entity/quote.dart';

sealed class QuoteLifecycleState extends State {}

final class QuoteReviewing extends QuoteLifecycleState {}

final class QuoteSent extends QuoteLifecycleState {}

final class QuoteApproved extends QuoteLifecycleState {}

final class QuoteRejected extends QuoteLifecycleState {}

final class QuoteWithdrawn extends QuoteLifecycleState {}

final class QuoteWasInvoiced extends QuoteLifecycleState {}

Type quoteStateType(QuoteState state) => switch (state) {
  QuoteState.reviewing => QuoteReviewing,
  QuoteState.sent => QuoteSent,
  QuoteState.approved => QuoteApproved,
  QuoteState.rejected => QuoteRejected,
  QuoteState.withdrawn => QuoteWithdrawn,
  QuoteState.invoiced => QuoteWasInvoiced,
};

Future<QuoteState> currentQuoteState(StateMachine machine) async {
  if (await machine.isInState<QuoteReviewing>()) {
    return QuoteState.reviewing;
  }
  if (await machine.isInState<QuoteSent>()) {
    return QuoteState.sent;
  }
  if (await machine.isInState<QuoteApproved>()) {
    return QuoteState.approved;
  }
  if (await machine.isInState<QuoteRejected>()) {
    return QuoteState.rejected;
  }
  if (await machine.isInState<QuoteWithdrawn>()) {
    return QuoteState.withdrawn;
  }
  if (await machine.isInState<QuoteWasInvoiced>()) {
    return QuoteState.invoiced;
  }
  throw StateError('Could not determine active quote state.');
}
