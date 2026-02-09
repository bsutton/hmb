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

enum ChargeMode {
  /// we calculate the charge by adding the margin to the cost.
  calculated,

  /// the user enters a charge directly and we ignore the costs.
  userDefined;

  static ChargeMode fromName(String? name) {
    const values = ChargeMode.values;

    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return ChargeMode.calculated;
  }
}
