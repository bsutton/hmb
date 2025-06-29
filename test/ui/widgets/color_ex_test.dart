/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/color_ex.dart';

void main() {
  testWidgets('color ex ...', (tester) async {
    // Original color
    const color = Color.fromARGB(255, 18, 52, 86); // A deep blue color
    print('Original Color: $color'); // Output: Color(0xff123456)

    // Convert to int
    final colorValue = color.toColorValue();
    print('Color as int: ${colorValue.toRadixString(16)}'); // Output: ff123456

    // Convert back to Color
    final newColor = Color(colorValue);
    print('New Color: $newColor'); // Output: Color(0xff123456)

    // Verify round-trip correctness
    expect(color, equals(newColor));
  });
}
