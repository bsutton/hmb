/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart';

import '../../../util/paths.dart'
    if (dart.library.ui) '../../../util/paths_flutter.dart';

/// Handles storing a photo into HMB's storage area and
/// then making a relative path available.
/// When storing paths to photos into the db we must
/// use a relative path so that we can the database
/// between devices and still access the photos on each device.
class CapturedPhoto {
  CapturedPhoto({required this.relativePath});

  CapturedPhoto.fromRelative({required this.relativePath});

  /// Save a captured photo to HMB's photo storage area.
  /// Call [relative] to obtain the path to save to the db.
  static Future<CapturedPhoto> saveToHMBStorage(String pathToPickedFile) async {
    final photosRootPath = await getPhotosRootPath();
    final fileName = basename(pathToPickedFile);
    final saveTo = join(photosRootPath, fileName);
    copy(pathToPickedFile, saveTo);

    return CapturedPhoto.fromAbsolute(absolutePathToPhoto: saveTo);
  }

  /// Path to the captured photo relative to HMB's main
  /// photo storage area as designated by photosRootPath which
  /// is different on each device.
  late final String relativePath;

  /// Get the abosolute path to the photo with HMB storage
  /// given a [relativePath] which is relative to the HMB storage.
  Future<String?> get absolutePath async =>
      join(await getPhotosRootPath(), relativePath);

  static Future<CapturedPhoto> fromAbsolute({
    required String absolutePathToPhoto,
  }) async {
    final relativePathToPhoto = relative(
      absolutePathToPhoto,
      from: await getPhotosRootPath(),
    );

    assert(
      relativePathToPhoto != absolutePathToPhoto,
      '''
The relative call failed probably because $relativePathToPhoto isn't relative to $absolutePathToPhoto''',
    );

    return CapturedPhoto(relativePath: relativePathToPhoto);
  }
}
