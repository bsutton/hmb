import '../database_helper.dart';

class BackupHistoryStore {
  static const operationBackup = 'backup';
  static const operationRestore = 'restore';
  static const operationPhotoSync = 'photo_sync';

  static Future<void> record({
    required String provider,
    required String operation,
    required bool success,
    String? error,
    DateTime? occurredAt,
  }) async {
    try {
      final db = DatabaseHelper.instance.database;
      final when = (occurredAt ?? DateTime.now()).toIso8601String();
      await db.insert('backup_history', {
        'provider': provider,
        'operation': operation,
        'success': success ? 1 : 0,
        'error': error,
        'occurred_at': when,
        'created_date': when,
        'modified_date': when,
      });
    } catch (_) {
      // Backup history should never block backup/restore/sync operations.
    }
  }

  static Future<DateTime?> latestSuccessfulBackup() async {
    try {
      final db = DatabaseHelper.instance.database;
      final rows = await db.query(
        'backup_history',
        columns: ['occurred_at'],
        where: 'operation = ? AND success = 1',
        whereArgs: [operationBackup],
        orderBy: 'occurred_at DESC, id DESC',
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      final raw = rows.first['occurred_at'] as String?;
      return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    } catch (_) {
      return null;
    }
  }
}
