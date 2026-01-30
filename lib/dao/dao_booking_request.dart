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

import 'package:sqflite_common/sqlite_api.dart';

import '../entity/booking_request.dart';
import 'dao.dart';

class DaoBookingRequest extends Dao<BookingRequest> {
  static const tableName = 'booking_request';
  DaoBookingRequest() : super(tableName);

  @override
  BookingRequest fromMap(Map<String, dynamic> map) =>
      BookingRequest.fromMap(map);

  Future<BookingRequest?> getByRemoteId(String remoteId) async {
    final db = withoutTransaction();
    final data = await db.query(
      tableName,
      where: 'remote_id = ?',
      whereArgs: [remoteId],
      limit: 1,
    );
    if (data.isEmpty) {
      return null;
    }
    return fromMap(data.first);
  }

  Future<List<BookingRequest>> getPending() =>
      getByStatuses([BookingRequestStatus.pending]);

  Future<int> countPending() => count(
    where: 'status = ?',
    whereArgs: [BookingRequestStatus.pending.ordinal],
  );

  Future<void> markImported(BookingRequest request) async {
    await update(request.copyWith(status: BookingRequestStatus.imported));
  }

  Future<List<BookingRequest>> getByStatuses(
    List<BookingRequestStatus> statuses,
  ) async {
    final db = withoutTransaction();
    if (statuses.isEmpty) {
      return [];
    }
    final placeholders = List.filled(statuses.length, '?').join(', ');
    final data = await db.query(
      tableName,
      where: 'status IN ($placeholders)',
      whereArgs: statuses.map((s) => s.ordinal).toList(),
      orderBy: 'createdDate desc',
    );
    return toList(data);
  }

  Future<void> createTable(Database db, int version) async {}
}
