/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../../../entity/tool.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/wizard.dart';
import '../../widgets/wizard_step.dart';
import 'receipt_step.dart';
import 'serial_no_step.dart';
import 'tool_details_step.dart';
import 'tool_photo_step.dart';

class ToolStockTakeWizard extends StatefulWidget {
  const ToolStockTakeWizard({
    required this.onFinish,
    super.key,
    this.cost,
    this.name,
  });
  final WizardCompletion onFinish;
  final Money? cost;
  final String? name;

  @override
  State<ToolStockTakeWizard> createState() => _ToolStockTakeWizardState();

  static Future<void> start({
    required BuildContext context,
    required WizardCompletion onFinish,
    required bool offerAnother,
    Money? cost,
    String? name,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ToolStockTakeWizard(
          cost: cost,
          name: name,
          onFinish: (reason) async {
            await onFinish(reason);

            if (reason == WizardCompletionReason.cancelled) {
              return;
            }

            if (!offerAnother || !context.mounted) {
              return;
            }

            // Show a dialog asking if the user wants to add another
            final addAnother = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Add Another?'),
                content: const Text(
                  'Would you like to run the stock take wizard again?',
                ),
                actions: [
                  HMBButton(
                    label: 'No',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                  HMBButton(
                    label: 'Yes',
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ],
              ),
            );

            // If the user chooses to add another, re-launch the wizard
            if ((addAnother ?? false) && context.mounted) {
              await start(
                context: context,
                onFinish: onFinish,
                offerAnother: offerAnother,
              );
            }
          },
        ),
      ),
    );
  }
}

class _ToolStockTakeWizardState extends State<ToolStockTakeWizard> {
  final wizardState = ToolWizardState();

  @override
  Widget build(BuildContext context) {
    final steps = <WizardStep>[
      ToolDetailsStep(wizardState, name: widget.name, cost: widget.cost),
      ToolPhotoStep(wizardState),
      SerialNumberStep(wizardState),
      ReceiptStep(wizardState),
    ];

    return Wizard(initialSteps: steps, onFinished: widget.onFinish);
  }
}

class ToolWizardState {
  Tool? tool;
}
