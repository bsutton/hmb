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

import '../../entity/entity.g.dart';
import 'package:money2/money2.dart';

class InvoiceOptions {
  List<int> selectedTaskIds = [];
  // ignore: omit_obvious_property_types
  bool billBookingFee = true;
  bool groupByTask;
  Contact contact;
  Percentage quoteMargin;
  Map<int, Percentage> taskMargins;

  InvoiceOptions({
    required this.selectedTaskIds,
    required this.billBookingFee,
    required this.groupByTask,
    required this.contact,
    Percentage? quoteMargin,
    Map<int, Percentage>? taskMargins,
  }) : quoteMargin = quoteMargin ?? Percentage.zero,
       taskMargins = taskMargins ?? {};
}
