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

enum ReceiptExpenseCategory {
  materials('materials', 'Materials'),
  tools('tools', 'Tools'),
  consumables('consumables', 'Consumables'),
  fuel('fuel', 'Fuel'),
  parking('parking', 'Parking'),
  vehicle('vehicle', 'Vehicle'),
  office('office', 'Office'),
  insurance('insurance', 'Insurance'),
  subcontractor('subcontractor', 'Subcontractor'),
  other('other', 'Other');

  const ReceiptExpenseCategory(this.code, this.label);

  final String code;
  final String label;

  static ReceiptExpenseCategory fromCode(String? code) =>
      ReceiptExpenseCategory.values.firstWhere(
        (category) => category.code == code,
        orElse: () => ReceiptExpenseCategory.materials,
      );
}
