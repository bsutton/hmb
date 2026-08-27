import 'package:fsm2/fsm2.dart';

sealed class QuoteLifecycleState extends State {}

final class QuoteReviewing extends QuoteLifecycleState {}

final class QuoteSent extends QuoteLifecycleState {}

final class QuoteApproved extends QuoteLifecycleState {}

final class QuoteRejected extends QuoteLifecycleState {}

final class QuoteWithdrawn extends QuoteLifecycleState {}

final class QuoteWasInvoiced extends QuoteLifecycleState {}
