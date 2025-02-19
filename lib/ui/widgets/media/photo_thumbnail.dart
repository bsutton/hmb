import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/material.dart';

import '../../../util/photo_meta.dart';
import '../color_ex.dart';
import 'full_screen_photo_view.dart';

class PhotoThumbnail extends StatelessWidget {
  PhotoThumbnail({
    required this.photoPath,
    required this.title,
    this.comment,
    super.key,
  }) : hasPhoto = photoPath != null && exists(photoPath);

  factory PhotoThumbnail.fromPhotoMeta({
    required PhotoMeta photoMeta,
    required String title,
    String? comment,
    Key? key,
  }) {
    final photoPath = photoMeta.absolutePathTo;

    return PhotoThumbnail(
      photoPath: photoPath,
      title: title,
      comment: comment,
      key: key,
    );
  }

  late final String? photoPath;
  final String title;
  final String? comment;
  late final bool hasPhoto;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      if (hasPhoto) {
        await _showFullScreenPhoto(context);
      }
    },
    child: Stack(
      children: [
        if (hasPhoto)
          Image.file(
            File(photoPath!),
            width: 100, // Thumbnail size, adjust as needed
            height: 100,
            fit: BoxFit.cover,
          )
        else
          Container(
            width: 100,
            height: 100,
            color: Colors.grey,
            child: const Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 40,
            ),
          ),
        if (hasPhoto)
          Positioned(
            right: 0,
            child: Container(
              color: Colors.black.withSafeOpacity(0.5),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.fullscreen, color: Colors.white),
            ),
          ),
      ],
    ),
  );

  Future<void> _showFullScreenPhoto(BuildContext context) async {
    await FullScreenPhotoViewer.show(
      context: context,
      imagePath: photoPath!,
      title: title,
      comment: comment,
    );
  }
}
