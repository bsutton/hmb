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

import '../../../dao/dao_photo.dart';
import '../../widgets/wizard_step.dart';
import 'capture_photo.dart';
import 'stock_take_wizard.dart';

class ToolPhotoStep extends WizardStep {
  ToolWizardState wizard;

  ToolPhotoStep(this.wizard) : super(title: 'Photo');

  @override
  Widget build(BuildContext context) => CapturePhoto(
    tool: wizard.tool!,
    comment: 'Tool Photo',
    title: 'CaptureTool Photo',
    onCaptured: (photo) => DaoPhoto().insert(photo),
  );
}
