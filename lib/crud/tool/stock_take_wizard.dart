import 'package:flutter/material.dart';

import '../../widgets/wizard.dart';
import '../../widgets/wizard_step.dart';
import 'serial_no_step.dart';
import 'tool_details_step.dart';
import 'tool_photo_step.dart';

class ToolStockTakeWizard extends StatelessWidget {
  const ToolStockTakeWizard({required this.onFinish, super.key});
  final WizardCompletion onFinish;

  @override
  Widget build(BuildContext context) {
    final steps = <WizardStep>[
      ToolDetailsStep(title: 'Details'),
      ToolPhotoStep(title: 'Photo'),
      SerialNumberStep(title: 'Serial No'),
    ];

    return Wizard(
      initialSteps: steps,
      onFinished: onFinish,
    );
  }
}
