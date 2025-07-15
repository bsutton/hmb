/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../src/appname.dart';
import '../../util/app_title.dart';
import '../../util/log.dart';
import '../widgets/wizard.dart';
import 'billing_page.dart';
import 'business_page.dart';
import 'contact_page.dart';
import 'integration_page.dart';
import 'intro_step.dart';

class SetupWizard extends StatefulWidget {
  const SetupWizard({required this.launchedFromSettings, super.key});

  /// True if launched from the settings dashboard
  final bool launchedFromSettings;

  @override
  _SetupWizardState createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  @override
  void initState() {
    super.initState();
    setAppTitle('$appName Setup Wizard'); // optional title setter
  }

  @override
  Widget build(BuildContext context) {
    // The wizard steps we want to show
    final steps = [
      IntroWizardStep(),
      BusinessWizardStep(),
      BillingWizardStep(),
      ContactWizardStep(),
      IntegrationWizardStep(),
    ];

    return Wizard(
      initialSteps: steps,
      onTransition:
          ({
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

        if (!mounted) {
          return;
        }

        if (widget.launchedFromSettings) {
          context.go('/home/settings');
        } else {
          context.go('/home');
        }
      },
    );
  }
}
