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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/photo_meta.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/media/captured_photo.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/media/photo_thumbnail.dart';

class CapturePhoto extends StatefulWidget {
  final Tool tool;
  final String title;
  final String comment;
  final Future<int> Function(Photo) onCaptured;
  
  const CapturePhoto({
    required this.tool,
    required this.title,
    required this.comment,
    required this.onCaptured,
    super.key,
  });


  @override
  State<CapturePhoto> createState() => _CapturePhotoState();
}

class _CapturePhotoState extends State<CapturePhoto> {
  final _photoController = PhotoController<Tool>(
    parent: null,
    parentType: ParentType.tool,
  );

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
          HMBButton.withIcon(
            label: 'Capture Photo',
            hint: 'Take a photo using the phones camera',
            icon: const Icon(Icons.camera_alt),
            onPressed: () => unawaited(
              _takePhoto(widget.title, (capturedPhoto) async {
                // Create a new Photo entity
                final newPhoto = Photo.forInsert(
                  parentId: widget.tool.id,
                  parentType: ParentType.tool,
                  filePath: capturedPhoto.relativePath,
                  comment: widget.comment,
                );
                photoId = await widget.onCaptured(newPhoto);

                setState(() {});
              }),
            ),
          ),
          if (photoId != null) ...[
            const SizedBox(height: 16),
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilderEx(
              // ignore: discarded_futures
              future: _getPhotoMeta(),
              builder: (context, meta) => PhotoThumbnail.fromPhotoMeta(
                photoMeta: meta!,
                title: meta.title,
                comment: meta.comment,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _takePhoto(
    String title,
    void Function(CapturedPhoto) onCapture,
  ) async {
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
