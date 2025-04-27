import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../util/app_title.dart';
import '../../util/log.dart';
import '../widgets/wizard.dart';
import 'billing_page.dart';
import 'business_page.dart';
import 'contact_page.dart';
import 'integration_page.dart';

class FirstRunWizard extends StatefulWidget {
  const FirstRunWizard({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FirstRunWizardState createState() => _FirstRunWizardState();
}

class _FirstRunWizardState extends State<FirstRunWizard> {
  @override
  void initState() {
    super.initState();
    setAppTitle('HMB Setup Wizard'); // optional title setter
  }

  @override
  Widget build(BuildContext context) {
    // The wizard steps we want to show
    final steps = [
      BusinessWizardStep(),
      BillingWizardStep(),
      ContactWizardStep(),
      IntegrationWizardStep(),
    ];

    return Wizard(
      initialSteps: steps,
      onTransition: ({
        required currentStep,
        required targetStep,
        required userOriginated,
      }) {
        Log.d(
          'Wizard transition from ${currentStep.title} to ${targetStep.title}.',
        );
      },
      onFinished: (reason) async {
        switch (reason) {
          case WizardCompletionReason.cancelled:
            // e.g. user clicked Cancel button
            Log.d('Wizard cancelled by user.');
          case WizardCompletionReason.completed:
            // e.g. user got to last step and clicked Next
            Log.d('Wizard completed successfully.');
          case WizardCompletionReason.backedOut:
            // e.g. user used hardware back button from the first step
            Log.d('Wizard closed using device back button.');
        }

        // After the wizard is done or cancelled, go somewhere
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          // If you have a named route for jobs, e.g.:
          context.go('/dashboard');
        }
      },
    );
  }
}
