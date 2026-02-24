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

class DaoJobAttachment extends Dao<JobAttachment> {
  static const tableName = 'job_attachment';

  DaoJobAttachment() : super(tableName);

  @override
  JobAttachment fromMap(Map<String, dynamic> map) => JobAttachment.fromMap(map);

  Future<List<JobAttachment>> getByJob(int jobId) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'modified_date DESC',
    );
    return toList(rows);
  }
}
