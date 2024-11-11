import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../../dao/dao_photo.dart';
import '../../entity/tool.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/wizard_step.dart';

class SerialNumberStep extends WizardStep {
  SerialNumberStep({required super.title});

  final TextEditingController _serialNumberController = TextEditingController();
  final PhotoController<Tool> _photoController =
      PhotoController<Tool>(parent: null, parentType: ParentType.tool);

  String? _serialPhotoPath;

  Future<void> _scanBarcode() async {
    if (_serialPhotoPath != null) {
      await _scanBarCodeFromfile(_serialPhotoPath!);
    }
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
            ElevatedButton(
              onPressed: _scanBarcode,
              child: const Text('Scan Barcode'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Serial Number Photo'),
              onPressed: () async => _takePhoto(
                'Serial Photo',
                (path) => setState(() {
                  _serialPhotoPath = path;
                }),
              ),
            ),
            if (_serialPhotoPath != null) ...[
              const SizedBox(height: 16),
              Text('Serial Number Photo:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Image.file(File(_serialPhotoPath!)),
            ],
          ],
        ),
      );

  Future<void> _takePhoto(String title, void Function(String) onCapture) async {
    final path = await _photoController.takePhoto();
    if (path != null) {
      onCapture(path.path);
    }
  }

  @override
  void dispose() {
    _serialNumberController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _scanBarCodeFromfile(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final barcodeScanner = BarcodeScanner();

    try {
      final barcodes = await barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        for (final barcode in barcodes) {
          final rawValue = barcode.rawValue;
          final format = barcode.format;

          // Use the barcode data (e.g., display it, save it, etc.)
          print('Barcode found! Value: $rawValue, Format: $format');

          // For example, update your serial number controller:
          setState(() {
            _serialNumberController.text = rawValue ?? '';
          });
        }
      } else {
        print('No barcode found in the image.');
        // Optionally, notify the user
        HMBToast.info('No barcode found in the image.');
      }
    } catch (e) {
      print('Error scanning barcode: $e');
      // Optionally, handle errors appropriately
      HMBToast.error('Error scanning barcode: $e');
    } finally {
      barcodeScanner.close();
    }
  }
}
