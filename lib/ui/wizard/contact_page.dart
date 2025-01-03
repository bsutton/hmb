import 'package:flutter/material.dart';

import '../crud/system/system_contact_screen.dart';
import '../widgets/wizard.dart';
import '../widgets/wizard_step.dart';

class ContactWizardStep extends WizardStep {
  ContactWizardStep() : super(title: 'Contact Information');

  final stateKey = GlobalKey<SystemContactInformationScreenState>();

  @override
  Future<void> onNext(BuildContext context, WizardStepTarget intendedStep,
      {required bool userOriginated}) async {
    if (await stateKey.currentState!.save(close: false)) {
      intendedStep.confirm();
    } else {
      intendedStep.cancel();
    }
  }

  @override
  Widget build(BuildContext context) => SystemContactInformationScreen(key: stateKey, showButtons: false);
}
