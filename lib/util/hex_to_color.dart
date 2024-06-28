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
