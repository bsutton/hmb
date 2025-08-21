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

import 'package:money2/money2.dart';

class XeroLineItem {
  final String description;
  final Fixed quantity;
  final Money unitAmount;
  final Money lineTotal;
  final String accountCode;
  final String itemCode;

  XeroLineItem({
    required this.description,
    required this.quantity,
    required this.unitAmount,
    required this.lineTotal,
    required this.accountCode,
    required this.itemCode,
  });

  Map<String, dynamic> toJson() => {
    'Description': description,
    'Quantity': quantity.toString(),
    'UnitAmount': unitAmount.format('0.##'),
    'LineAmount': lineTotal.format('0.##'),
    'AccountCode': accountCode,
    'ItemCode': itemCode,
  };
}
