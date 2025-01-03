import 'dart:async';

import 'package:flutter/material.dart';

import '../crud/system/system_business_screen.dart';
import '../widgets/wizard.dart';
import '../widgets/wizard_step.dart';

class BusinessWizardStep extends WizardStep {
  BusinessWizardStep() : super(title: 'Business Details');

  final _stateKey = GlobalKey<SystemBusinessScreenState>();

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
      SystemBusinessScreen(key: _stateKey, showButtons: false);
}
