import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/entity/trip_log.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'test_database_config.dart';

void main() {
  test('v219 preserves jobs and starts tracking disabled', () async {
    final directory = Directory.systemTemp.createTempSync('hmb-trip-upgrade-');
    final db = await CliDatabaseFactory().openDatabase(
      '${directory.path}/test.db',
      options: OpenDatabaseOptions(
        onConfigure: configureDisposableTestDatabase,
      ),
    );
    try {
      for (final path in [
        'test/sql/trip_log_v213.sql',
        'assets/sql/upgrade_scripts/v219.sql',
      ]) {
        for (final sql in await parseSqlFile(await File(path).readAsString())) {
          await db.execute(sql);
        }
      }
      expect(await db.query('job'), hasLength(1));
      final settings = TripSettings.fromMap(
        (await db.query('trip_settings')).single,
      );
      expect(settings.enabled, isFalse);
      expect(settings.routeLookupEnabled, isFalse);
      expect(await db.query('trip_log'), isEmpty);
    } finally {
      await db.close();
      directory.deleteSync(recursive: true);
    }
  });

  test('v222 preserves existing trips and adds address origins', () async {
    final directory = Directory.systemTemp.createTempSync('hmb-trip-v222-');
    final db = await CliDatabaseFactory().openDatabase(
      '${directory.path}/test.db',
      options: OpenDatabaseOptions(),
    );
    try {
      for (final path in [
        'test/sql/trip_log_v213.sql',
        'assets/sql/upgrade_scripts/v219.sql',
      ]) {
        for (final sql in await parseSqlFile(await File(path).readAsString())) {
          await db.execute(sql);
        }
      }
      final siteId = (await db.query('site')).single['id'];
      final jobId = (await db.query('job')).single['id'];
      await db.insert('trip_log', {
        'departed_at': '2026-01-01T08:00:00Z',
        'arrived_at': '2026-01-01T08:30:00Z',
        'from_latitude': -37.0,
        'from_longitude': 145.0,
        'to_latitude': -37.1,
        'to_longitude': 145.1,
        'from_home': 1,
        'distance_metres': 12000,
        'duration_seconds': 1800,
        'site_id': siteId,
        'job_id': jobId,
        'purpose': 'Existing trip',
        'business': 1,
      });
      for (final sql in await parseSqlFile(
        await File('assets/sql/upgrade_scripts/v222.sql').readAsString(),
      )) {
        await db.execute(sql);
      }
      final trip = (await db.query('trip_log')).single;
      expect(trip['id'], 1);
      expect(trip['distance_metres'], 12000);
      expect(trip['site_id'], siteId);
      expect(trip['job_id'], jobId);
      expect(trip['purpose'], 'Existing trip');
      expect(trip['classified'], 1);
      expect(trip['from_address'], isNull);
      expect(
        await db.rawQuery("PRAGMA table_info('trip_log')"),
        contains(
          predicate(
            (Map<String, Object?> row) => row['name'] == 'from_address',
          ),
        ),
      );
      expect(
        await db.rawQuery("PRAGMA index_list('trip_log')"),
        contains(
          predicate(
            (Map<String, Object?> row) => row['name'] == 'trip_log_arrived_idx',
          ),
        ),
      );
    } finally {
      await db.close();
      directory.deleteSync(recursive: true);
    }
  });
}
