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
  Thumbnail({required this.source, required this.target});

  static Future<Thumbnail> fromMeta(PhotoMeta meta) async {
    final source = meta.absolutePathTo;

    await meta.resolve();

    final absolutePath = meta.absolutePathTo;
    final thumbnailDir = await _getThumbnailDirectory();
    final target = p.join(
      thumbnailDir,
      '${p.basenameWithoutExtension(absolutePath)}.jpg',
    );

    if (!core.exists(absolutePath)) {
      throw InvalidPathException(absolutePath);
    }

    return Thumbnail(source: source, target: target);
  }

  String source;
  String target;

  bool exists() => core.exists(source);

  // Function to generate a thumbnail (to be run in a background isolate)
  Future<String?> generateThumbnail() async {
    print('generating thumbnail: $source');

    final imageFile = File(source);
    if (!exists()) {
      return null;
    }

    final image = img.decodeImage(imageFile.readAsBytesSync());
    if (image == null) {
      return null;
    }

    final thumbnail = img.copyResize(image, width: 80, height: 80);
    File(target).writeAsBytesSync(img.encodeJpg(thumbnail));
    return target;
  }

  // Helper function to get the thumbnail directory
  static Future<String> _getThumbnailDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final thumbnailDir = p.join(tempDir.path, 'thumbnails');
    createDir(thumbnailDir, recursive: true);
    return thumbnailDir;
  }

  Future<Thumbnail?> generate(ComputeManager computeManager) async {
    if (exists()) {
      return this;
    }

    // Generate thumbnail in a background isolate
    return computeManager.enqueueCompute((thumbnail) async {
      await thumbnail.generateThumbnail();
      return thumbnail;
    }, this);
  }
}
