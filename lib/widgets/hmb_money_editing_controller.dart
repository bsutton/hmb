import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../util/money_ex.dart';

class HMBMoneyEditingController extends TextEditingController {
  HMBMoneyEditingController({Money? money})
      : super(text: money?.amount.toString() ?? '0.00');

  Money? get money => MoneyEx.tryParse(text);
}
