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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:photo_view/photo_view.dart';
import 'package:strings/strings.dart';

import '../desktop_back_gesture_suppress.dart';
import '../hmb_toast.dart';
import '../icons/hmb_close_icon.dart';
import '../icons/hmb_copy_icon.dart';
import '../layout/layout.g.dart';

class FullScreenPhotoViewer extends StatelessWidget {
  final String imagePath;
  final String title;
  final String? comment;

  const FullScreenPhotoViewer({
    required this.imagePath,
    required this.title,
    required this.comment,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        DesktopBackGestureSuppress(
          child: PhotoView(
            imageProvider: FileImage(File(imagePath)),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.0,
            initialScale: PhotoViewComputedScale.contained,
          ),
        ),
        Positioned(
          top: 40,
          left: 20,
          right: 20,
          child: HMBColumn(
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
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),

        /// action icons (copy and close)
        Positioned(
          top: 40,
          right: 20,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HMBCopyIcon(
                onPressed: () async {
                  try {
                    await Pasteboard.writeFiles([imagePath]);
                    HMBToast.info('Image copied to clipboard');
                    // ignore: avoid_catches_without_on_clauses
                  } catch (e) {
                    HMBToast.error('Failed to copy image to clipboard');
                  }
                },
                hint: 'Copy the photo to the clopboard',
              ),
              HMBCloseIcon(onPressed: () async => Navigator.of(context).pop()),
            ],
          ),
        ),
      ],
    ),
  );

  static Future<void> show({
    required BuildContext context,
    required String imagePath,
    required String title,
    required String? comment,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => FullScreenPhotoViewer(
          imagePath: imagePath,
          title: title,
          comment: comment,
        ),
      ),
    );
  }
}
