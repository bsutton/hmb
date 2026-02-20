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

import 'package:strings/strings.dart';

import 'app_settings.dart';

Future<String?> buildPdfTaxDisplayText() async {
  final mode = await AppSettings.getTaxDisplayMode();
  if (mode == TaxDisplayMode.none) {
    return null;
  }

  final label = (await AppSettings.getTaxLabel()).trim();
  if (Strings.isBlank(label)) {
    return null;
  }

  final rate = (await AppSettings.getTaxRatePercentText()).trim();
  final rateText = Strings.isBlank(rate) ? '' : ' ($rate%)';

  return switch (mode) {
    TaxDisplayMode.none => null,
    TaxDisplayMode.inclusive => 'All prices include $label$rateText',
    TaxDisplayMode.exclusive => 'All prices exclude $label$rateText',
  };
}
