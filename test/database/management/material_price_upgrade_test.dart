@Tags(['flutter'])
library;

import 'package:dcli/dcli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:hmb/database/versions/pre_upgrade/pre_upgrade_208.dart';
import 'package:path/path.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test('v208 replaces legacy material columns with item prices', () async {
    final dbPath = join(createTempDir(), 'material_price_v208.db');
    final db = await CliDatabaseFactory().openDatabase(
      dbPath,
      options: OpenDatabaseOptions(),
    );

    try {
      await db.execute(_legacyTaskItemTable);
      await db.execute('''
CREATE TABLE receipt_task_item (
  receipt_id INTEGER NOT NULL,
  task_item_id INTEGER NOT NULL REFERENCES task_item(id)
)
''');
      await db.execute('''
CREATE INDEX receipt_task_item_task_item_idx
ON receipt_task_item(task_item_id)
''');
      await db.insert('task_item', _legacyRow);
      await db.insert('receipt_task_item', {
        'receipt_id': 1,
        'task_item_id': 2820,
      });
      await db.execute('PRAGMA foreign_keys = ON');

      final sql = await ProjectScriptSource().loadSQL(
        'assets/sql/upgrade_scripts/v208.sql',
      );
      await pre208Upgrade(db);
      for (final statement in await parseSqlFile(sql)) {
        await db.execute(statement);
      }
      await post208Upgrade(db);

      final columns = await db.rawQuery('PRAGMA table_info(task_item)');
      final names = {for (final column in columns) column['name']! as String};
      final row = (await db.query('task_item')).single;
      final foreignKeys = await db.rawQuery(
        'PRAGMA foreign_key_list(receipt_task_item)',
      );
      final indexes = await db.rawQuery('PRAGMA index_list(receipt_task_item)');

      expect(
        names,
        containsAll(<String>{
          'estimated_price_mode',
          'estimated_quantity',
          'estimated_unit_cost',
          'estimated_items_per_package',
          'actual_price_mode',
          'actual_quantity',
          'actual_unit_cost',
          'actual_items_per_package',
        }),
      );
      expect(
        names,
        isNot(
          containsAll(<String>{
            'estimated_material_quantity',
            'estimated_material_unit_cost',
            'actual_material_quantity',
            'actual_material_unit_cost',
            'actual_cost',
          }),
        ),
      );
      expect(row['estimated_price_mode'], 'items');
      expect(row['estimated_quantity'], 2000);
      expect(row['estimated_unit_cost'], 150);
      expect(row['actual_price_mode'], 'items');
      expect(row['actual_quantity'], 2000);
      expect(row['actual_unit_cost'], 10500);
      expect(foreignKeys.single['table'], 'task_item');
      expect(
        (await db.query('receipt_task_item')).single['task_item_id'],
        2820,
      );
      expect(
        indexes.map((index) => index['name']),
        contains('receipt_task_item_task_item_idx'),
      );
    } finally {
      await db.close();
      delete(dbPath);
    }
  });
}

const _legacyTaskItemTable = '''
CREATE TABLE task_item (
  id INTEGER PRIMARY KEY,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  task_id INTEGER NOT NULL,
  description TEXT NOT NULL,
  item_type_id INTEGER NOT NULL,
  estimated_material_unit_cost INTEGER,
  estimated_material_quantity INTEGER,
  estimated_labour_hours INTEGER,
  estimated_labour_cost INTEGER,
  margin INTEGER NOT NULL,
  total_line_charge INTEGER,
  charge_mode TEXT NOT NULL,
  completed INTEGER NOT NULL,
  billed INTEGER NOT NULL,
  invoice_line_id INTEGER,
  measurement_type TEXT,
  dimension1 INTEGER,
  dimension2 INTEGER,
  dimension3 INTEGER,
  units TEXT,
  url TEXT,
  purpose TEXT,
  supplier_id INTEGER,
  labour_entry_mode TEXT NOT NULL,
  actual_material_unit_cost INTEGER,
  actual_material_quantity INTEGER,
  actual_cost INTEGER,
  source_task_item_id INTEGER,
  is_return INTEGER NOT NULL
)
''';

final _legacyRow = <String, Object?>{
  'id': 2820,
  'created_date': '2026-07-01T00:00:00.000',
  'modified_date': '2026-07-01T00:00:00.000',
  'task_id': 1220,
  'description': 'Scrubbed material',
  'item_type_id': 2,
  'estimated_material_unit_cost': 150,
  'estimated_material_quantity': 2000,
  'estimated_labour_hours': null,
  'estimated_labour_cost': null,
  'margin': 0,
  'total_line_charge': null,
  'charge_mode': 'calculated',
  'completed': 1,
  'billed': 0,
  'invoice_line_id': null,
  'measurement_type': 'length',
  'dimension1': 0,
  'dimension2': 0,
  'dimension3': 0,
  'units': 'm',
  'url': '',
  'purpose': '',
  'supplier_id': null,
  'labour_entry_mode': 'Hours',
  'actual_material_unit_cost': 10500,
  'actual_material_quantity': 2000,
  'actual_cost': 21000,
  'source_task_item_id': null,
  'is_return': 0,
};
