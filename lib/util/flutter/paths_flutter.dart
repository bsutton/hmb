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

/// DO NOT import this library directly. Instead
/// import paths.dart as it has conditional
/// imports based on whether we are running under
/// flutter or cli.
library;

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart' as pp;

typedef Path = String;

Path? _photosRootPath;
Path? _settingsPath;
Path? _tempDirectory;

/// Device specific to where all photos are stored for HMB.
Future<String> getPhotosRootPath() async =>
    _photosRootPath ??= (await pp.getApplicationDocumentsDirectory()).path;

/// Device specific to where all photos are stored for HMB.
Future<String> getSettingsPath() async => _settingsPath ??= join(
  (await pp.getApplicationDocumentsDirectory()).path,
  'settings',
);

/// temporary directory which may be transient between
/// reboots
Future<Path> getTemporaryDirectory() async =>
    _tempDirectory ??= (await pp.getTemporaryDirectory()).path;
