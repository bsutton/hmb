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

import '../entity/entity.g.dart';
import 'dao.dart';

class DaoCreditNoteLine extends Dao<CreditNoteLine> {
  static const tableName = 'credit_note_line';
  DaoCreditNoteLine() : super(tableName);

  @override
  CreditNoteLine fromMap(Map<String, dynamic> map) =>
      CreditNoteLine.fromMap(map);
}
