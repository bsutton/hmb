/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

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
