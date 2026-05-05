import 'dart:io';

import 'package:pasteboard/pasteboard.dart';

Future<void> copyImageToClipboard(String imagePath) async {
  if (Platform.isLinux) {
    final copied = await Pasteboard.writeFiles([imagePath]);
    if (!copied) {
      throw Exception('Failed to copy file reference');
    }
    return;
  }

  final bytes = await File(imagePath).readAsBytes();
  await Pasteboard.writeImage(bytes);
}
