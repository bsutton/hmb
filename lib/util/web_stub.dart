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
*/

/// Used to import nothing when doing a conditional import.
library;

/// Dummy script for non-windows platforms.
class DartScript {
  // ignore: prefer_constructors_over_static_methods
  static DartScript self() => DartScript();

  String get pathToScript => '';
}
