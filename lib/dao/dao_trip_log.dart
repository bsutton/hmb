import 'package:sqflite_common/sqlite_api.dart';

import '../database/management/database_helper.dart';
import '../entity/trip_log.dart';

class DaoTripLog {
  Database get _db => DatabaseHelper().database;

  Future<TripSettings> settings() async =>
      TripSettings.fromMap((await _db.query('trip_settings')).single);

  Future<void> saveSettings(TripSettings settings) async {
    if (settings.rateCentsPerKm < 0 ||
        (settings.home != null && !settings.home!.valid)) {
      throw ArgumentError('Invalid travel settings');
    }
    await _db.transaction((txn) async {
      await txn.update('trip_settings', settings.toMap(), where: 'id = 1');
      // Never bridge an interval during which logging was disabled.
      if (!settings.enabled) {
        await txn.delete('trip_observation');
      }
    });
  }

  Future<int?> observe(TripPoint point, DateTime at) async {
    if (!point.valid) {
      throw ArgumentError('Invalid coordinates');
    }
    return await _db.transaction((txn) async {
      final settings = TripSettings.fromMap(
        (await txn.query('trip_settings')).single,
      );
      if (!settings.enabled) {
        return null;
      }
      final last = (await txn.query('trip_observation')).firstOrNull;
      final lastAt = last == null
          ? null
          : DateTime.parse(last['observed_at']! as String).toLocal();
      if (lastAt != null && !at.isAfter(lastAt)) {
        return null;
      }
      final sameDay =
          lastAt != null &&
          lastAt.year == at.year &&
          lastAt.month == at.month &&
          lastAt.day == at.day;
      final origin = sameDay
          ? TripPoint(
              (last!['latitude']! as num).toDouble(),
              (last['longitude']! as num).toDouble(),
            )
          : settings.home;
      int? id;
      if (origin != null && origin.distanceTo(point) > 500) {
        id = await txn.insert('trip_log', {
          'departed_at': sameDay ? lastAt.toUtc().toIso8601String() : null,
          'arrived_at': at.toUtc().toIso8601String(),
          'from_latitude': origin.latitude,
          'from_longitude': origin.longitude,
          'to_latitude': point.latitude,
          'to_longitude': point.longitude,
          'from_home': sameDay ? 0 : 1,
        });
        final nearSites =
            (await txn.query(
                  'site',
                  where: 'latitude IS NOT NULL AND longitude IS NOT NULL',
                ))
                .where(
                  (row) =>
                      TripPoint(
                        (row['latitude']! as num).toDouble(),
                        (row['longitude']! as num).toDouble(),
                      ).distanceTo(point) <=
                      100,
                )
                .toList();
        if (nearSites.length == 1) {
          final siteId = nearSites.single['id']! as int;
          final jobs = await txn.query(
            'job',
            columns: ['id'],
            where: 'site_id = ?',
            whereArgs: [siteId],
          );
          await txn.update(
            'trip_log',
            {
              'site_id': siteId,
              'job_id': jobs.length == 1 ? jobs.single['id'] : null,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      // Keep the anchor while stationary to prevent many small steps from
      // hiding a >500m move. Update only its last observed time.
      final anchor = id == null && sameDay ? origin! : point;
      await txn.insert('trip_observation', {
        'id': 1,
        'latitude': anchor.latitude,
        'longitude': anchor.longitude,
        'observed_at': at.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return id;
    });
  }

  Future<List<TripLog>> between(DateTime start, DateTime end) async =>
      (await _db.query(
        'trip_log',
        where: 'arrived_at >= ? AND arrived_at < ?',
        whereArgs: [
          start.toUtc().toIso8601String(),
          end.toUtc().toIso8601String(),
        ],
        orderBy: 'arrived_at DESC',
      )).map(TripLog.fromMap).toList();

  Future<List<TripLog>> pendingRoutes() async => (await _db.query(
    'trip_log',
    where: 'distance_metres IS NULL',
    orderBy: 'id',
    limit: 20,
  )).map(TripLog.fromMap).toList();

  Future<void> saveRoute(TripLog trip, int metres, int seconds) async {
    if (metres < 0 || seconds < 0) {
      throw ArgumentError('Invalid route distance or duration');
    }
    await _db.update(
      'trip_log',
      {
        'distance_metres': metres,
        'duration_seconds': seconds,
        if (trip.departedAt == null)
          'departed_at': trip.arrivedAt
              .subtract(Duration(seconds: seconds))
              .toUtc()
              .toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [trip.id],
    );
  }

  Future<void> classify(
    int id, {
    required bool business,
    required String purpose,
  }) async {
    await _db.update(
      'trip_log',
      {'business': business ? 1 : 0, 'purpose': purpose.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
