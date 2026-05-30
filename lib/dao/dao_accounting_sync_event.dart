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

import '../entity/entity.g.dart';
import 'dao.dart';

class DaoAccountingSyncEvent extends Dao<AccountingSyncEvent> {
  static const tableName = 'accounting_sync_event';
  DaoAccountingSyncEvent() : super(tableName);

  @override
  AccountingSyncEvent fromMap(Map<String, dynamic> map) =>
      AccountingSyncEvent.fromMap(map);

  Future<AccountingSyncEvent> enqueue({
    required String provider,
    required String entityType,
    required AccountingSyncOperation operation,
    int? localId,
    String? externalId,
    String? contentHash,
    String? payload,
    Transaction? transaction,
  }) async {
    final existing = await _pendingMatchingEvent(
      provider: provider,
      entityType: entityType,
      operation: operation,
      localId: localId,
      externalId: externalId,
      transaction: transaction,
    );
    if (existing != null) {
      return existing;
    }
    final event = AccountingSyncEvent.forInsert(
      provider: provider,
      entityType: entityType,
      operation: operation,
      localId: localId,
      externalId: externalId,
      contentHash: contentHash,
      payload: payload,
    );
    await insert(event, transaction);
    return event;
  }

  Future<List<AccountingSyncEvent>> getPending({
    String? provider,
    AccountingSyncOperation? operation,
  }) async {
    final where = <String>['status = ?'];
    final args = <Object?>[AccountingSyncEventStatus.pending.ordinal];
    if (provider != null) {
      where.add('provider = ?');
      args.add(provider);
    }
    if (operation != null) {
      where.add('operation = ?');
      args.add(operation.ordinal);
    }
    return toList(
      await withoutTransaction().query(
        tableName,
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: 'created_date ASC, id ASC',
      ),
    );
  }

  Future<List<AccountingSyncEvent>> getByEntity({
    required String provider,
    required String entityType,
    required int localId,
  }) async => toList(
    await withoutTransaction().query(
      tableName,
      where: 'provider = ? AND entity_type = ? AND local_id = ?',
      whereArgs: [provider, entityType, localId],
      orderBy: 'created_date ASC, id ASC',
    ),
  );

  Future<void> markSynced(AccountingSyncEvent event) async {
    await update(
      event.copyWith(
        status: AccountingSyncEventStatus.synced,
        lastAttemptAt: DateTime.now(),
        attemptCount: event.attemptCount + 1,
        lastError: '',
      ),
    );
  }

  Future<void> markFailed(AccountingSyncEvent event, Object error) async {
    await update(
      event.copyWith(
        status: AccountingSyncEventStatus.pending,
        lastAttemptAt: DateTime.now(),
        attemptCount: event.attemptCount + 1,
        lastError: error.toString(),
      ),
    );
  }

  Future<void> markConflict({
    required String provider,
    required String entityType,
    required String reason,
    int? localId,
    String? externalId,
  }) async {
    final event = AccountingSyncEvent.forInsert(
      provider: provider,
      entityType: entityType,
      localId: localId,
      externalId: externalId,
      operation: AccountingSyncOperation.update,
      status: AccountingSyncEventStatus.conflict,
      lastError: reason,
    );
    await insert(event);
  }

  Future<void> supersedePendingCreates({
    required String provider,
    required String entityType,
    required int localId,
    Transaction? transaction,
  }) async {
    await withinTransaction(transaction).update(
      tableName,
      {
        'status': AccountingSyncEventStatus.superseded.ordinal,
        'modified_date': DateTime.now().toIso8601String(),
      },
      where: '''
provider = ?
AND entity_type = ?
AND local_id = ?
AND operation = ?
AND status = ?
''',
      whereArgs: [
        provider,
        entityType,
        localId,
        AccountingSyncOperation.create.ordinal,
        AccountingSyncEventStatus.pending.ordinal,
      ],
    );
  }

  Future<AccountingSyncEvent?> _pendingMatchingEvent({
    required String provider,
    required String entityType,
    required AccountingSyncOperation operation,
    int? localId,
    String? externalId,
    Transaction? transaction,
  }) async {
    final where = <String>[
      'provider = ?',
      'entity_type = ?',
      'operation = ?',
      'status = ?',
    ];
    final args = <Object?>[
      provider,
      entityType,
      operation.ordinal,
      AccountingSyncEventStatus.pending.ordinal,
    ];
    if (localId == null) {
      where.add('local_id IS NULL');
    } else {
      where.add('local_id = ?');
      args.add(localId);
    }
    if (externalId == null) {
      where.add('external_id IS NULL');
    } else {
      where.add('external_id = ?');
      args.add(externalId);
    }
    final rows = await withinTransaction(
      transaction,
    ).query(tableName, where: where.join(' AND '), whereArgs: args, limit: 1);
    return rows.isEmpty ? null : fromMap(rows.first);
  }
}
