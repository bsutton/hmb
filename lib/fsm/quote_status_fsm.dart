import 'package:fsm2/fsm2.dart';

import '../entity/quote.dart';
import 'quote_events.dart';
import 'quote_states.dart';

/// Side-effect-free quote lifecycle graph. Persistence belongs to the
/// lifecycle event dispatcher.
Future<StateMachine> buildQuoteMachine(
  Quote quote,
) => StateMachine.create(production: true, (graph) {
  switch (quote.state) {
    case QuoteState.reviewing:
      graph.initialState<QuoteReviewing>();
    case QuoteState.sent:
      graph.initialState<QuoteSent>();
    case QuoteState.approved:
      graph.initialState<QuoteApproved>();
    case QuoteState.rejected:
      graph.initialState<QuoteRejected>();
    case QuoteState.withdrawn:
      graph.initialState<QuoteWithdrawn>();
    case QuoteState.invoiced:
      graph.initialState<QuoteWasInvoiced>();
  }

  graph
    ..state<QuoteReviewing>(
      (state) => state
        ..on<SendQuote, QuoteSent>()
        ..on<RejectQuoteEvent, QuoteRejected>()
        ..on<RejectQuoteAndJob, QuoteRejected>()
        ..on<AmendQuote, QuoteRejected>(),
    )
    ..state<QuoteSent>(
      (state) => state
        ..on<SendQuote, QuoteSent>()
        ..on<ApproveQuoteEvent, QuoteApproved>()
        ..on<RejectQuoteEvent, QuoteRejected>()
        ..on<RejectQuoteAndJob, QuoteRejected>()
        ..on<WithdrawQuote, QuoteWithdrawn>()
        ..on<AmendQuote, QuoteRejected>(),
    )
    ..state<QuoteApproved>(
      (state) => state
        ..on<SendQuote, QuoteApproved>()
        ..on<UnapproveQuote, QuoteSent>()
        ..on<QuoteInvoiced, QuoteWasInvoiced>()
        ..on<RejectQuoteEvent, QuoteRejected>()
        ..on<RejectQuoteAndJob, QuoteRejected>()
        ..on<AmendQuote, QuoteRejected>(),
    )
    ..state<QuoteWasInvoiced>(
      (state) => state
        ..on<SendQuote, QuoteWasInvoiced>()
        ..on<QuoteInvoiced, QuoteWasInvoiced>(),
    )
    ..state<QuoteRejected>((state) => state..on<AmendQuote, QuoteRejected>())
    ..state<QuoteWithdrawn>((state) => state..on<AmendQuote, QuoteWithdrawn>());
});
