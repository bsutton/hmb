/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:ui';

extension ColorExtensions on Color {
  /// Returns a new color that matches this color with the alpha channel
  /// replaced with the given `opacity` (which ranges from 0.0 to 1.0).
  ///
  /// Throws an assertion error if the opacity is out of range.
  Color withSafeOpacity(double opacity) {
    assert(
      opacity >= 0.0 && opacity <= 1.0,
      'Opacity must be between 0.0 and 1.0.',
    );
    return withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
  }

  // int toColorValue() =>
  //     (a.toInt() << 24) | (r.toInt() << 16) | (g.toInt() << 8) | b.toInt();

  int toColorValue() =>
      ((a * 255).toInt() << 24) |
      ((r * 255).toInt() << 16) |
      ((g * 255).toInt() << 8) |
      (b * 255).toInt();
}
