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

class DaoCreditNote extends Dao<CreditNote> {
  static const tableName = 'credit_note';
  DaoCreditNote() : super(tableName);

  @override
  CreditNote fromMap(Map<String, dynamic> map) => CreditNote.fromMap(map);

  Future<CreditNote?> getByExternalCreditNoteId(
    String externalCreditNoteId,
  ) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'external_credit_note_id = ?',
      whereArgs: [externalCreditNoteId],
      limit: 1,
    );
    return getFirstOrNull(rows);
  }

  Future<List<CreditNote>> getUnsyncedForProvider(String provider) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'external_credit_note_id IS NULL OR external_credit_note_id = ?',
        whereArgs: [''],
        orderBy: 'credit_date ASC, id ASC',
      ),
    );
  }

  Future<void> markExternal({
    required CreditNote creditNote,
    required String externalCreditNoteId,
  }) async {
    await update(
      creditNote.copyWith(externalCreditNoteId: externalCreditNoteId),
    );
  }
}
