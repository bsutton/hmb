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

import '../widgets/layout/hmb_column.dart';
import '../widgets/wizard.dart';
import '../widgets/wizard_step.dart';

class IntroWizardStep extends WizardStep {
  IntroWizardStep() : super(title: 'Welcome');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Hold My Beer (HMB)',
            style: theme.textTheme.headlineMedium,
          ),
          Text('''
We are almost ready to get started.

HMB helps a sole trader manage jobs, customers, quoting, invoicing,
receipts, photos, scheduling, and basic accounting in one place.

The setup wizard asks for the details needed to prepare invoices,
quotes, customer messages, storage, and optional integrations.

You can leave most fields blank and come back later from Settings.
Your data stays on your device unless you enable a backup or integration.

Tap Next to begin.
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
