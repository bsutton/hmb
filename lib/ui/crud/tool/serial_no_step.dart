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

// import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../../../dao/dao_photo.dart';
import '../../../dao/dao_tool.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/wizard.dart';
import '../../widgets/wizard_step.dart';
import 'capture_photo.dart';
import 'stock_take_wizard.dart';

class SerialNumberStep extends WizardStep {
  SerialNumberStep(this.toolWizardState) : super(title: 'Serial No');

  final _serialNumberController = TextEditingController();

  ToolWizardState toolWizardState;
  String? _serialPhotoPath;

  Future<void> _scanBarcode() async {
    if (_serialPhotoPath != null) {
      // await _scanBarCodeFromfile(_serialPhotoPath!);
    }
  }

  @override
  Future<void> onNext(
    BuildContext context,
    WizardStepTarget intendedStep, {
    required bool userOriginated,
  }) async {
    final daoTool = DaoTool();
    final tool = toolWizardState.tool!.copyWith(
      serialNumber: _serialNumberController.text,
    );
    await daoTool.update(tool);
    toolWizardState.tool = tool;

    // ignore: use_build_context_synchronously
    return super.onNext(context, intendedStep, userOriginated: userOriginated);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        TextField(
          controller: _serialNumberController,
          decoration: const InputDecoration(labelText: 'Serial Number'),
        ),
        HMBButton(
          label: 'Scan Barcode',
          onPressed: _scanBarcode,
          hint:
              """Scan a tool's serial number bar code to extract the serial number""",
        ),

        const SizedBox(height: 24),
        CapturePhoto(
          tool: toolWizardState.tool!,
          comment: 'Serial Number',
          title: 'Capture Serial Number',
          onCaptured: (photo) async {
            final photoId = await DaoPhoto().insert(photo);
            toolWizardState.tool = toolWizardState.tool!.copyWith(
              serialNumberPhotoId: photoId,
            );
            await DaoTool().update(toolWizardState.tool!);
            return photoId;
          },
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _serialNumberController.dispose();
    super.dispose();
  }

  // Future<void> _scanBarCodeFromfile(String imagePath) async {
  //   final inputImage = InputImage.fromFilePath(imagePath);
  //   final barcodeScanner = BarcodeScanner();

  //   try {
  //     final barcodes = await barcodeScanner.processImage(inputImage);

  //     if (barcodes.isNotEmpty) {
  //       for (final barcode in barcodes) {
  //         final rawValue = barcode.rawValue;
  //         final format = barcode.format;

  //         // Use the barcode data (e.g., display it, save it, etc.)
  //         print('Barcode found! Value: $rawValue, Format: $format');

  //         // For example, update your serial number controller:
  //         setState(() {
  //           _serialNumberController.text = rawValue ?? '';
  //         });
  //       }
  //     } else {
  //       print('No barcode found in the image.');
  //       // Optionally, notify the user
  //       HMBToast.info('No barcode found in the image.');
  //     }
  //     // ignore: avoid_catches_without_on_clauses
  //   } catch (e) {
  //     print('Error scanning barcode: $e');
  //     // Optionally, handle errors appropriately
  //     HMBToast.error('Error scanning barcode: $e');
  //   } finally {
  //     await barcodeScanner.close();
  //   }
  // }
}
