import 'package:flutter/material.dart';

import '../crud/system/system_integration_screen.dart';
import '../widgets/wizard.dart';
import '../widgets/wizard_step.dart';

class IntegrationWizardStep extends WizardStep {
  IntegrationWizardStep() : super(title: 'System Integration');

  final _stateKey = GlobalKey<SystemIntegrationScreenState>();

  @override
  Future<void> onNext(BuildContext context, WizardStepTarget intendedStep,
      {required bool userOriginated}) async {
    if (await _stateKey.currentState!.save(close: false)) {
      intendedStep.confirm();
    } else {
      intendedStep.cancel();
    }
  }

  @override
  Widget build(BuildContext context) =>
      SystemIntegrationScreen(key: _stateKey, showButtons: false);
}
