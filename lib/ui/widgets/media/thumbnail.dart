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

import 'dart:developer' show log;
import 'dart:io';

import 'package:dcli_core/dcli_core.dart' as core;
import 'package:dcli_core/dcli_core.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../util/compute_manager.dart';
import '../../../util/exceptions.dart';
import '../../../util/photo_meta.dart';

class Thumbnail {
  Thumbnail({required this.source, required this.pathToThumbNail});

  static Future<Thumbnail> fromMeta(PhotoMeta meta) async {
    await meta.resolve();
    final source = meta.absolutePathTo;

    final thumbnailDir = await _getThumbnailDirectory();
    final target = p.join(
      thumbnailDir,
      '${p.basenameWithoutExtension(source)}.jpg',
    );

    if (!core.exists(source)) {
      throw InvalidPathException(source);
    }

    return Thumbnail(source: source, pathToThumbNail: target);
  }

  String source;
  String pathToThumbNail;

  bool exists() => core.exists(source);

  // Function to generate a thumbnail (to be run in a background isolate)
  // returns a path to the generated image
  Future<String?> _generateImage() async {
    log('generating thumbnail image for: $source');

    final imageFile = File(source);
    if (!exists()) {
      return null;
    }

    final image = img.decodeImage(imageFile.readAsBytesSync());
    if (image == null) {
      return null;
    }

    final thumbnail = img.copyResize(image, width: 80, height: 80);
    File(pathToThumbNail).writeAsBytesSync(img.encodeJpg(thumbnail));
    return pathToThumbNail;
  }

  // Helper function to get the thumbnail directory
  static Future<String> _getThumbnailDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final thumbnailDir = p.join(tempDir.path, 'thumbnails');
    if (!core.exists(thumbnailDir)) {
      createDir(thumbnailDir, recursive: true);
    }
    return thumbnailDir;
  }

  Future<void> generate(
    ComputeManager<Thumbnail, Thumbnail> computeManager,
  ) async {
    if (core.exists(pathToThumbNail)) {
      return;
    }

    // Generate thumbnail in a background isolate
    await computeManager.enqueueCompute((thumbnail) async {
      await thumbnail._generateImage();

      return thumbnail;
    }, this);
  }
}
