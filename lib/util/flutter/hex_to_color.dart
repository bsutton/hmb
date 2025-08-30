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


import 'dart:ui';

Color hexToColor(String hexColor) {
  // Remove the leading `#` if present
  var hex = hexColor.replaceAll('#', '');

  // If the hex code is 6 characters long, add the opacity value (ff)
  if (hex.length == 6) {
    hex = 'ff$hex';
  }

  // Parse the hex string to an integer and create a Color object
  return Color(int.parse(hex, radix: 16));
}
