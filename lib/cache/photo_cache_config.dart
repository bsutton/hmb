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

class PhotoCacheConfig {
  /// Maximum on-disk size of the compressed-image cache.
  final int maxBytes;

  /// WebP quality (roughly JPEG 88–92).
  final int webpQuality;

  /// Target long edge in pixels for compression.
  final int longEdge;

  /// Keep EXIF (timestamp/GPS/orientation).
  final bool preserveExif;

  const PhotoCacheConfig({
    required this.maxBytes,
    required this.webpQuality,
    required this.longEdge,
    this.preserveExif = true,
  });
  factory PhotoCacheConfig.general({required int maxBytes}) => PhotoCacheConfig(
    maxBytes: maxBytes, // 500 MB default
    webpQuality: 75, // good detail vs size
    longEdge: 3500, // px; 4000 for forensic
  );

  factory PhotoCacheConfig.forensic() => const PhotoCacheConfig(
    maxBytes: 500 * 1024 * 1024,
    webpQuality: 80,
    longEdge: 4000,
  );
}
