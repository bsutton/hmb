import 'package:flutter/material.dart';
import '../widgets/wizard.dart';
import '../widgets/wizard_step.dart';

class IntroWizardStep extends WizardStep {
  IntroWizardStep() : super(title: 'Welcome');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Hold My Beer',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text('''
We’re almost ready to get started.

We’ll ask you for some basic business information such as your name, business name, and contact details.

This information is used to:
• Generate invoices and quotes  
* Add a signature to your emails
• Set your hourly rates and booking fees  
• Configure your business hours and scheduling  
• Integrate with accounting software like Xero  

🔒 Your data is never uploaded or shared — it stays on your device.

You can hit 'Cancel' and come back to this screen later.

Tap "Next" to begin.
            ''', style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  @override
  Future<void> onNext(
    BuildContext context,
    WizardStepTarget intendedStep, {
    required bool userOriginated,
  }) async {
    intendedStep.confirm();
  }
}
