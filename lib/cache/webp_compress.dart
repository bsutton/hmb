/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
       with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for
     third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:io';
import 'dart:typed_data';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Compression job payload used across the isolate boundary.
class WebPCompressJob {
  final String srcPath;

  final String dstPath;

  final int longEdge;

  final int quality;

  final bool keepExif;

  WebPCompressJob({
    required this.srcPath,
    required this.dstPath,
    required this.longEdge,
    required this.quality,
    required this.keepExif,
  });

  static Future<CompressResult> run(WebPCompressJob job) async {
    try {
      final src = job.srcPath;
      if (!exists( src)) {
        return CompressResult(success: false, error: 'Source not found');
      }
      final bytes = await File(src).readAsBytes();

      // We set both minWidth/minHeight to longEdge. The plugin will keep
      // aspect ratio and downscale so that the long edge == longEdge.
      final out = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: job.longEdge,
        minHeight: job.longEdge,
        format: CompressFormat.webp,
        quality: job.quality,
        keepExif: job.keepExif,
      );

      final dst = File(job.dstPath);
      await dst.create(recursive: true);
      await dst.writeAsBytes(Uint8List.fromList(out), flush: true);

      return CompressResult(success: true, error: null);
    } catch (e) {
      return CompressResult(success: false, error: '$e');
    }
  }
}

class CompressResult {
  final bool success;

  final String? error;

  CompressResult({required this.success, required this.error});
}
