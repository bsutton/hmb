/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../desktop_back_gesture_suppress.dart';

class AttachmentPdfViewer extends StatelessWidget {
  final String filePath;
  final String title;

  const AttachmentPdfViewer({
    required this.filePath,
    required this.title,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: DesktopBackGestureSuppress(child: PdfViewer.file(filePath)),
  );

  static Future<void> show({
    required BuildContext context,
    required String filePath,
    required String title,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            AttachmentPdfViewer(filePath: filePath, title: title),
      ),
    );
  }
}
