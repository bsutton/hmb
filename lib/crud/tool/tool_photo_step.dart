import 'dart:io';

import 'package:flutter/material.dart';

import '../../dao/dao_photo.dart';
import '../../entity/tool.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/wizard_step.dart';

class ToolPhotoStep extends WizardStep {
  ToolPhotoStep({required super.title});

  final PhotoController<Tool> _photoController =
      PhotoController<Tool>(parent: null, parentType: ParentType.tool);

  String? _toolPhotoPath;

  Future<void> _takePhoto(String title, void Function(String) onCapture) async {
    final path = await _photoController.takePhoto();
    if (path != null) {
      onCapture(path.path);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture Tool Photo'),
                onPressed: () async => _takePhoto(
                  'Tool Photo',
                  (path) => setState(() {
                    _toolPhotoPath = path;
                  }),
                ),
              ),
              if (_toolPhotoPath != null) ...[
                const SizedBox(height: 16),
                Text('Tool Photo:',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Image.file(
                  File(_toolPhotoPath!),
                  width: 200,
                  height: 200,
                ),
              ],
            ],
          ),
        ),
      );
}
