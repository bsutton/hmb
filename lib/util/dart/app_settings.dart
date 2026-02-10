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

import 'package:settings_yaml/settings_yaml.dart';

import 'paths.dart';

class AppSettings {
  static const photoCacheMaxMbDefault = 100;
  static const _photoCacheMaxMbKey = 'photoCacheMaxMb';

  static Future<int> getPhotoCacheMaxMb() async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    final value = settings[_photoCacheMaxMbKey];

    if (value is int && value > 0) {
      return value;
    }

    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return photoCacheMaxMbDefault;
  }

  static Future<void> setPhotoCacheMaxMb(int megabytes) async {
    final safeValue = megabytes <= 0 ? photoCacheMaxMbDefault : megabytes;
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    settings[_photoCacheMaxMbKey] = safeValue;
    await settings.save();
  }
}
