import 'package:flutter/material.dart';

import '../../../dao/dao_photo.dart';
import '../../../dao/dao_tool.dart';
import '../../widgets/wizard_step.dart';
import 'capture_photo.dart';
import 'stock_take_wizard.dart';

class ReceiptStep extends WizardStep {
  ReceiptStep(this.wizard) : super(title: 'Receipt');

  ToolWizardState wizard;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            CapturePhoto(
                tool: wizard.tool!,
                comment: 'Receipt',
                title: 'Capture Receipt',
                onCaptured: (photo) async {
                  final photoId = await DaoPhoto().insert(photo);
                  wizard.tool = wizard.tool!.copyWith(receiptPhotoId: photoId);
                  await DaoTool().update(wizard.tool!);
                  return photoId;
                })
          ],
        ),
      );
}
