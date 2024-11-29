import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../../../util/money_ex.dart';

class HMBMoneyEditingController extends TextEditingController {
  HMBMoneyEditingController({Money? money})
      : super(text: money == null || money.isZero ? '' : money.format('#.##'));

  Money? get money => MoneyEx.tryParse(text);

  set money(Money? money) {
    text = money == null || money.isZero ? '' : money.format('#.##');
  }
}
