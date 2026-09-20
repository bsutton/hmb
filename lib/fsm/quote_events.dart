import 'package:fsm2/fsm2.dart';

import '../entity/quote.dart';

sealed class QuoteEvent extends Event {
  final Quote quote;

  QuoteEvent(this.quote);

  String get name;
}

class SendQuote extends QuoteEvent {
  SendQuote(super.quote);
  @override
  String get name => 'SendQuote';
}

class ApproveQuoteEvent extends QuoteEvent {
  ApproveQuoteEvent(super.quote);
  @override
  String get name => 'ApproveQuote';
}

class UnapproveQuote extends QuoteEvent {
  UnapproveQuote(super.quote);
  @override
  String get name => 'UnapproveQuote';
}

class RejectQuoteEvent extends QuoteEvent {
  RejectQuoteEvent(super.quote);
  @override
  String get name => 'RejectQuote';
}

class RejectQuoteAndJob extends QuoteEvent {
  RejectQuoteAndJob(super.quote);
  @override
  String get name => 'RejectQuoteAndJob';
}

class WithdrawQuote extends QuoteEvent {
  WithdrawQuote(super.quote);
  @override
  String get name => 'WithdrawQuote';
}

class AmendQuote extends QuoteEvent {
  AmendQuote(super.quote);
  @override
  String get name => 'AmendQuote';
}

class QuoteInvoiced extends QuoteEvent {
  QuoteInvoiced(super.quote);
  @override
  String get name => 'QuoteInvoiced';
}
