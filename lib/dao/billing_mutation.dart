import 'package:sqflite_common/sqlite_api.dart';

/// DAO-layer outbox: source writes and invalidation commit together.
/// Raw SQL/batch billing writes must explicitly enqueue their affected jobs.
class BillingMutation {
  static final _enabled = Expando<bool>();

  static void enable(Database db) => _enabled[db] = true;

  static bool enabled(Database db) => _enabled[db] ?? false;

  static const tables = {
    'job',
    'task',
    'time_entry',
    'task_item',
    'quote',
    'milestone',
    'quote_line',
    'quote_line_group',
    'invoice',
    'invoice_line',
    'invoice_line_group',
    'system',
  };

  static Future<void> enqueue(DatabaseExecutor db, Iterable<int> jobs) async {
    for (final id in jobs.toSet()) {
      await db.rawInsert(
        '''
INSERT INTO job_billing_state(job_id, billing_required)
SELECT id, 1 FROM job WHERE id = ? AND is_stock = 0
ON CONFLICT(job_id) DO UPDATE SET
  billing_required = 1, revision = revision + 1,
  attempts = 0, retry_after = 0, failed = 0
''',
        [id],
      );
    }
  }

  static Future<Set<int>> jobs(
    DatabaseExecutor db,
    String table,
    Iterable<Map<String, Object?>> rows,
  ) async {
    final ids = <int>{};
    for (final row in rows) {
      if (table == 'system') {
        ids.addAll(
          (await db.query(
            'job',
            columns: ['id'],
          )).map((row) => row['id']! as int),
        );
        break;
      }
      if (table == 'job') {
        ids.add(row['id']! as int);
      } else if (row['job_id'] case final int id) {
        ids.add(id);
      } else {
        final (parent, key) = switch (table) {
          'time_entry' || 'task_item' => ('task', 'task_id'),
          'milestone' ||
          'quote_line' ||
          'quote_line_group' => ('quote', 'quote_id'),
          'invoice_line' || 'invoice_line_group' => ('invoice', 'invoice_id'),
          _ => throw StateError('Missing billing owner for $table'),
        };
        final parents = await db.query(
          parent,
          columns: ['job_id'],
          where: 'id = ?',
          whereArgs: [row[key]],
        );
        ids.addAll(parents.map((row) => row['job_id']! as int));
      }
    }
    return ids;
  }

  /// Access timestamps and presentation-only edits are not billing events.
  static bool changed(
    String table,
    Map<String, Object?> old,
    Map<String, Object?> values,
  ) {
    final fields = switch (table) {
      'job' => {
        'billing_type',
        'status_id',
        'hourly_rate',
        'booking_fee',
        'booking_fee_invoiced',
        'is_stock',
      },
      'task' => {'job_id', 'billing_type', 'task_status_id'},
      'system' => {'default_booking_fee', 'default_hourly_rate'},
      _ => null,
    };
    return values.entries.any(
      (entry) =>
          entry.key != 'modified_date' &&
          entry.key != 'created_date' &&
          (fields == null || fields.contains(entry.key)) &&
          old[entry.key] != entry.value,
    );
  }
}
