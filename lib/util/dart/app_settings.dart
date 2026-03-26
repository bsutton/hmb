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
import 'plaster_layout_scoring.dart';

enum TaxDisplayMode {
  none,
  inclusive,
  exclusive;

  static TaxDisplayMode fromName(String? name) {
    for (final mode in TaxDisplayMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }
    return TaxDisplayMode.none;
  }
}

class AppSettings {
  static const photoCacheMaxMbDefault = 100;
  static const _photoCacheMaxMbKey = 'photoCacheMaxMb';
  static const defaultProfitMarginTextDefault = '0';
  static const _defaultProfitMarginTextKey = 'defaultProfitMarginText';
  static const _taxDisplayModeKey = 'taxDisplayMode';
  static const _taxLabelKey = 'taxLabel';
  static const _taxRateKey = 'taxRatePercent';
  static const _plasterExtraSheetWeightKey = 'plasterExtraSheetWeight';
  static const _plasterJointLengthWeightKey = 'plasterJointLengthWeight';
  static const _plasterCutPieceWeightKey = 'plasterCutPieceWeight';
  static const _plasterHighJointWeightKey = 'plasterHighJointWeight';
  static const _plasterSmallPieceWeightKey = 'plasterSmallPieceWeight';
  static const _plasterFragmentationWeightKey =
      'plasterFragmentationWeight';

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

  static Future<String> getDefaultProfitMarginText() async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    final value = settings[_defaultProfitMarginTextKey];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }

    return defaultProfitMarginTextDefault;
  }

  static Future<void> setDefaultProfitMarginText(String value) async {
    final sanitized = value.trim().isEmpty
        ? defaultProfitMarginTextDefault
        : value.trim();
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    settings[_defaultProfitMarginTextKey] = sanitized;
    await settings.save();
  }

  static Future<TaxDisplayMode> getTaxDisplayMode() async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    return TaxDisplayMode.fromName(settings.asString(_taxDisplayModeKey));
  }

  static Future<void> setTaxDisplayMode(TaxDisplayMode mode) async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    settings[_taxDisplayModeKey] = mode.name;
    await settings.save();
  }

  static Future<String> getTaxLabel() async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    return settings.asString(_taxLabelKey);
  }

  static Future<void> setTaxLabel(String value) async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    settings[_taxLabelKey] = value.trim();
    await settings.save();
  }

  static Future<String> getTaxRatePercentText() async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    final value = settings[_taxRateKey];
    if (value is num) {
      return value.toString();
    }
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  static Future<void> setTaxRatePercentText(String value) async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    settings[_taxRateKey] = value.trim();
    await settings.save();
  }

  static Future<PlasterLayoutScoring> getPlasterLayoutScoring() async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    const defaults = PlasterLayoutScoring.defaults();

    int readInt(String key, int fallback) {
      final value = settings[key];
      if (value is int) {
        return value;
      }
      if (value is String) {
        return int.tryParse(value.trim()) ?? fallback;
      }
      return fallback;
    }

    return PlasterLayoutScoring(
      extraSheetWeight: readInt(
        _plasterExtraSheetWeightKey,
        defaults.extraSheetWeight,
      ),
      jointLengthWeight: readInt(
        _plasterJointLengthWeightKey,
        defaults.jointLengthWeight,
      ),
      cutPieceWeight: readInt(
        _plasterCutPieceWeightKey,
        defaults.cutPieceWeight,
      ),
      highJointWeight: readInt(
        _plasterHighJointWeightKey,
        defaults.highJointWeight,
      ),
      smallPieceWeight: readInt(
        _plasterSmallPieceWeightKey,
        defaults.smallPieceWeight,
      ),
      fragmentationWeight: readInt(
        _plasterFragmentationWeightKey,
        defaults.fragmentationWeight,
      ),
    );
  }

  static Future<void> setPlasterLayoutScoring(
    PlasterLayoutScoring scoring,
  ) async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    settings[_plasterExtraSheetWeightKey] = scoring.extraSheetWeight;
    settings[_plasterJointLengthWeightKey] = scoring.jointLengthWeight;
    settings[_plasterCutPieceWeightKey] = scoring.cutPieceWeight;
    settings[_plasterHighJointWeightKey] = scoring.highJointWeight;
    settings[_plasterSmallPieceWeightKey] = scoring.smallPieceWeight;
    settings[_plasterFragmentationWeightKey] = scoring.fragmentationWeight;
    await settings.save();
  }
}
