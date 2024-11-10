import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:strings/strings.dart';

class FullScreenPhotoViewer extends StatelessWidget {
  const FullScreenPhotoViewer({
    required this.imagePath,
    required this.title,
    required this.comment,
    super.key,
  });

  final String imagePath;
  final String title;
  final String? comment;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PhotoView(
              imageProvider: FileImage(File(imagePath)),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2.0,
              initialScale: PhotoViewComputedScale.contained,
            ),
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  /// title
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  /// comment
                  if (Strings.isNotBlank(comment))
                    Text(
                      comment!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),

            /// close icon.
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      );

  static Future<void> show(
      {required BuildContext context,
      required String imagePath,
      required String title,
      required String? comment}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (context) => FullScreenPhotoViewer(
              imagePath: imagePath, title: title, comment: comment)),
    );
  }
}
