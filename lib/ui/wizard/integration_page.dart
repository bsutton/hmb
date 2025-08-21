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

import 'package:flutter/material.dart';

import '../crud/system/xero_integration_screen.dart';
import '../widgets/wizard.dart';
import '../widgets/wizard_step.dart';

class IntegrationWizardStep extends WizardStep {
  IntegrationWizardStep() : super(title: 'System Integration');

  final _stateKey = GlobalKey<XeroIntegrationScreenState>();

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
      XeroIntegrationScreen(key: _stateKey, showButtons: false);
}
