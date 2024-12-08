import 'package:flutter/material.dart';

import '../../../entity/tool.dart';
import '../../widgets/wizard.dart';
import '../../widgets/wizard_step.dart';
import 'receipt_step.dart';
import 'serial_no_step.dart';
import 'tool_details_step.dart';
import 'tool_photo_step.dart';

class ToolStockTakeWizard extends StatefulWidget {
  const ToolStockTakeWizard({required this.onFinish, super.key});
  final WizardCompletion onFinish;

  @override
  State<ToolStockTakeWizard> createState() => _ToolStockTakeWizardState();
}

class _ToolStockTakeWizardState extends State<ToolStockTakeWizard> {
  final wizardState = ToolWizardState();

  @override
  Widget build(BuildContext context) {
    final steps = <WizardStep>[
      ToolDetailsStep(wizardState),
      ToolPhotoStep(wizardState),
      SerialNumberStep(wizardState),
      ReceiptStep(wizardState),
    ];

    return Wizard(
      initialSteps: steps,
      onFinished: widget.onFinish,
    );
  }
}

class ToolWizardState {
  Tool? tool;
}
