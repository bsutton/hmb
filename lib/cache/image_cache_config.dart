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
/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 GPL terms per repo license.
*/

import 'hmb_image_cache.dart';

enum ImageVariantType { general, pdf, thumb, raw }

/// Hard-coded, unified quality profiles.
/// Tune here, not at call sites.
class ImageCacheConfig {
  /// LRU budget across *all* cached variants.
  final int maxBytes;
  static const defaultMaxMegabytes = 100;
  static const defaultMaxBytes = defaultMaxMegabytes * 1024 * 1024;

  // Display: good zoom detail at small size. WebP.
  static const generalLongEdge = 3500;

  static const generalWebpQuality = 75;

  static const generalKeepExif = true;

  // PDF: smaller, encoder-friendly. JPEG.
  // 1600px long edge ≈ good on A4 at typical image sizes.
  static const pdfLongEdge = 1600;

  static const pdfJpegQuality = 70;

  // Thumbnail: small grid/list previews. JPEG.
  static const thumbWidth = 200;

  static const thumbHeight = 200;

  static const thumbJpegQuality = 70;

  Future<void> Function(ImageVariant variant, String targetPath) downloader;

  Compressor compressor;

  ImageCacheConfig({
    required this.downloader,
    required this.compressor,
    this.maxBytes = defaultMaxBytes,
  });
}
