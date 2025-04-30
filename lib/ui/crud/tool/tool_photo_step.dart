import 'package:flutter/material.dart';

import '../../../dao/dao_photo.dart';
import '../../widgets/wizard_step.dart';
import 'capture_photo.dart';
import 'stock_take_wizard.dart';

class ToolPhotoStep extends WizardStep {
  ToolPhotoStep(this.wizard) : super(title: 'Photo');

  ToolWizardState wizard;

  @override
  Widget build(BuildContext context) => CapturePhoto(
    tool: wizard.tool!,
    comment: 'Tool Photo',
    title: 'CaptureTool Photo',
    // ignore: discarded_futures
    onCaptured: (photo) => DaoPhoto().insert(photo),
  );
}
