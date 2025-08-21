/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:flutter/material.dart';

import '../crud/system/system_business_screen.dart';
import '../widgets/wizard.dart';
import '../widgets/wizard_step.dart';

class BusinessWizardStep extends WizardStep {
  final _stateKey = GlobalKey<SystemBusinessScreenState>();

  BusinessWizardStep() : super(title: 'Business Details');

  @override
  Future<void> onNext(
    BuildContext context,
    WizardStepTarget intendedStep, {
    required bool userOriginated,
  }) async {
    if (await _stateKey.currentState!.save(close: false)) {
      intendedStep.confirm();
    } else {
      intendedStep.cancel();
    }
  }

  @override
  Widget build(BuildContext context) =>
      SystemBusinessScreen(key: _stateKey, showButtons: false);
}
