import 'package:money2/money2.dart';

String statementBalanceLabel(Money balance) =>
    balance.isNegative ? 'Credit balance' : 'Balance due';
