import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test('v231 restores only proved approval and audits exactly once', () async {
    final db = await CliDatabaseFactory().openDatabase(
      ':memory:',
      options: OpenDatabaseOptions(),
    );
    Future<void> apply(String sql) async {
      for (final statement in await parseSqlFile(sql)) {
        await db.execute(statement);
      }
    }

    try {
      for (final path in [
        'test/sql/voided_invoice_cancellation_v229.sql',
        'assets/sql/upgrade_scripts/v212.sql',
        'assets/sql/upgrade_scripts/v230.sql',
      ]) {
        await apply(File(path).readAsStringSync());
      }
      await db.execute('ALTER TABLE quote ADD COLUMN modified_date TEXT;');
      final jobs = await db.query('job');
      final invoices = await db.query('invoice');
      final milestones = await db.query('milestone');
      final allocations = await db.query('billing_allocation');
      final sql = File(
        'assets/sql/upgrade_scripts/v231.sql',
      ).readAsStringSync();
      await apply(sql);
      await apply(sql); // Interrupted app startup may replay the script.
      final quotes = await db.query('quote', orderBy: 'id');
      expect(quotes.map((q) => q['state']), [
        'approved',
        'invoiced',
        'invoiced',
      ]);
      expect(await db.query('job'), jobs);
      expect(await db.query('invoice'), invoices);
      expect(await db.query('milestone'), milestones);
      expect(await db.query('billing_allocation'), allocations);
      final audit = (await db.query('lifecycle_transition')).single;
      expect(audit['from_state'], 'invoiced');
      expect(audit['to_state'], 'approved');
      expect(audit['aggregate_id'], 178);
      await expectLater(
        db.update('quote', {'state': 'approved'}, where: 'id = 179'),
        throwsException,
      );
    } finally {
      await db.close();
    }
  });

  test('v232 accepts released links and skips deleted draft history', () async {
    final db = await CliDatabaseFactory().openDatabase(
      ':memory:',
      options: OpenDatabaseOptions(),
    );
    Future<void> apply(String path) async {
      for (final statement in await parseSqlFile(
        File(path).readAsStringSync(),
      )) {
        await db.execute(statement);
      }
    }

    try {
      await apply('test/sql/voided_invoice_cancellation_v229.sql');
      await apply('assets/sql/upgrade_scripts/v212.sql');
      await apply('assets/sql/upgrade_scripts/v230.sql');
      await db.execute('ALTER TABLE quote ADD COLUMN modified_date TEXT;');
      await db.execute(
        'INSERT INTO quote VALUES '
        "(181, 1, 'invoiced', 10000, NULL), "
        "(182, 1, 'invoiced', 10000, NULL), "
        "(183, 1, 'invoiced', 10000, NULL)",
      );
      await db.execute(
        'INSERT INTO billing_allocation VALUES '
        "(99, 'quote', 178, '2026-11-01'), "
        "(8, 'quote', 181, '2026-11-01'), "
        "(99, 'quote', 182, '2026-11-01'), "
        "(8, 'quote', 183, '2026-11-01')",
      );
      await db.execute('ALTER TABLE quote ADD COLUMN created_date TEXT;');
      await db.execute('ALTER TABLE milestone ADD COLUMN created_date TEXT;');
      await db.execute(
        'ALTER TABLE billing_allocation ADD COLUMN created_date TEXT;',
      );
      await db.execute("UPDATE quote SET created_date = '2026-01-01';");
      await db.execute(
        "UPDATE quote SET created_date = '2026-09-01' WHERE id = 183;",
      );
      await db.execute(
        "UPDATE billing_allocation SET created_date = '2026-05-01';",
      );
      await apply('assets/sql/upgrade_scripts/v231.sql');
      expect(await db.query('lifecycle_transition'), isEmpty);
      final allocations = await db.query('billing_allocation');

      await apply('assets/sql/upgrade_scripts/v232.sql');
      await apply('assets/sql/upgrade_scripts/v232.sql');

      final eligible = await db.query('cancellation_rejectable_quote');
      expect(eligible.map((q) => q['id']), unorderedEquals([178, 181]));
      expect(await db.query('billing_allocation'), allocations);
      final audit = (await db.query('lifecycle_transition')).single;
      expect(audit['aggregate_id'], 178);
      expect(audit['to_state'], 'approved');
    } finally {
      await db.close();
    }
  });
}
