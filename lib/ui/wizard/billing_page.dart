import 'dart:async';

import 'package:flutter/material.dart';

import '../crud/system/system_billing_screen.dart';
import '../widgets/wizard.dart';
import '../widgets/wizard_step.dart';

class BillingWizardStep extends WizardStep {
  BillingWizardStep() : super(title: 'Billing Details');

  final stateKey = GlobalKey<SystemBillingScreenState>();

  @override
  Future<void> onNext(
    BuildContext context,
    WizardStepTarget intendedStep, {
    required bool userOriginated,
  }) async {
    if (await stateKey.currentState!.save(close: false)) {
      intendedStep.confirm();
    } else {
      intendedStep.cancel();
    }
  }

  @override
  Widget build(BuildContext context) =>
      SystemBillingScreen(key: stateKey, showButtons: false);
}
