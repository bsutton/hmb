import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/_index.g.dart';
import '../../../entity/_index.g.dart';
import '../../../entity/tool.dart';
import '../../../util/photo_meta.dart';
import '../../widgets/media/captured_photo.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/media/photo_thumbnail.dart';

class CapturePhoto extends StatefulWidget {
  const CapturePhoto(
      {required this.tool,
      required this.title,
      required this.comment,
      required this.onCaptured,
      super.key});

  final Tool tool;
  final String title;
  final String comment;
  final Future<int> Function(Photo) onCaptured;

  @override
  State<CapturePhoto> createState() => _CapturePhotoState();
}

class _CapturePhotoState extends State<CapturePhoto> {
  final PhotoController<Tool> _photoController =
      PhotoController<Tool>(parent: null, parentType: ParentType.tool);

  int? photoId;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture Photo'),
                onPressed: () async => _takePhoto(
                  widget.title,
                  (capturedPhoto) async {
                    // Create a new Photo entity
                    final newPhoto = Photo.forInsert(
                      parentId: widget.tool.id,
                      parentType: 'tool',
                      filePath: capturedPhoto.relativePath,
                      comment: widget.comment,
                    );
                    photoId = await  widget.onCaptured(newPhoto);

                    setState(() {});
                  },
                ),
              ),
              if (photoId != null) ...[
                const SizedBox(height: 16),
                Text(widget.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                FutureBuilderEx(
                    // ignore: discarded_futures
                    future: _getPhotoMeta(),
                    builder: (context, meta) => PhotoThumbnail.fromPhotoMeta(
                        photoMeta: meta!,
                        title: meta.title,
                        comment: meta.comment))
              ],
            ],
          ),
        ),
      );

  Future<void> _takePhoto(
      String title, void Function(CapturedPhoto) onCapture) async {
    final path = await _photoController.takePhoto();
    if (path != null) {
      onCapture(path);
    }
  }

  Future<PhotoMeta> _getPhotoMeta() async {
    final photo = await DaoPhoto().getById(photoId);
    final meta = PhotoMeta.fromPhoto(photo: photo!);
    await meta.resolve();
    return meta;
  }
}