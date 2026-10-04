import 'package:material_ui/material_ui.dart';

import '../tools/trip_log_settings_screen.dart';
import '../widgets/wizard.dart';
import '../widgets/wizard_step.dart';

class TripLoggingWizardStep extends WizardStep {
  final _stateKey = GlobalKey<TripLogSettingsScreenState>();

  TripLoggingWizardStep() : super(title: 'Trip Logging');

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
      TripLogSettingsScreen(key: _stateKey, showButtons: false);
}
