import 'package:sqflite_common/sqlite_api.dart';

import '../database/management/database_helper.dart';
import '../entity/trip_log.dart';

class DaoTripLog {
  Database get _db => DatabaseHelper().database;

  Future<TripSettings> settings() async =>
      TripSettings.fromMap((await _db.query('trip_settings')).single);

  Future<void> saveSettings(TripSettings settings) async {
    if (settings.rateCentsPerKm < 0 ||
        (settings.home != null && !settings.home!.valid) ||
        settings.alternateOriginAddress.length > 1000) {
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

  Future<int?> observe(
    TripPoint point,
    DateTime at, {
    String? originAddress,
  }) async {
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
      final addressOrigin = sameDay ? null : originAddress?.trim();
      int? id;
      if ((origin != null && origin.distanceTo(point) > 500) ||
          (origin == null &&
              addressOrigin != null &&
              addressOrigin.isNotEmpty)) {
        id = await txn.insert('trip_log', {
          'departed_at': sameDay ? lastAt.toUtc().toIso8601String() : null,
          'arrived_at': at.toUtc().toIso8601String(),
          'from_latitude': origin?.latitude,
          'from_longitude': origin?.longitude,
          'from_address': origin == null ? addressOrigin : null,
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

  Future<List<TripLog>> pendingRoutes({int? afterId}) async => (await _db.query(
    'trip_log',
    where: afterId == null
        ? 'distance_metres IS NULL'
        : 'distance_metres IS NULL AND id > ?',
    whereArgs: afterId == null ? null : [afterId],
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
        'distance_source': 'route',
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

  Future<void> saveManualDistance(int tripId, int metres) async {
    if (metres <= 0) {
      throw ArgumentError('Trip distance must be greater than zero');
    }
    await _db.update(
      'trip_log',
      {'distance_metres': metres, 'distance_source': 'manual'},
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  Future<int?> startGpsTrip(
    TripPoint point,
    DateTime at, {
    int? siteId,
    int? jobId,
  }) async {
    if (!point.valid) throw ArgumentError('Invalid coordinates');
    return _db.transaction((txn) async {
      final settings = TripSettings.fromMap(
        (await txn.query('trip_settings')).single,
      );
      if (!settings.enabled || !settings.gpsTrackingEnabled) return null;
      if (settings.activeGpsTripId != null) return settings.activeGpsTripId;
      final id = await txn.insert('trip_log', {
        'departed_at': at.toUtc().toIso8601String(),
        'arrived_at': at.toUtc().toIso8601String(),
        'from_latitude': point.latitude,
        'from_longitude': point.longitude,
        'to_latitude': point.latitude,
        'to_longitude': point.longitude,
        'from_home': 0,
        'distance_metres': 0,
        'duration_seconds': 0,
        'distance_source': 'gps',
        'site_id': siteId,
        'job_id': jobId,
      });
      await txn.update('trip_settings', {
        'active_gps_trip_id': id,
      }, where: 'id = 1');
      return id;
    });
  }

  Future<void> recordGpsPosition(
    int tripId,
    TripPoint point,
    DateTime at,
  ) async {
    if (!point.valid) throw ArgumentError('Invalid coordinates');
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'trip_log',
        where: 'id = ?',
        whereArgs: [tripId],
      );
      if (rows.isEmpty) return;
      final trip = rows.single;
      final previousAt = DateTime.parse(trip['arrived_at']! as String);
      final nextAt = at.toUtc();
      if (!nextAt.isAfter(previousAt)) return;
      final previous = TripPoint(
        (trip['to_latitude']! as num).toDouble(),
        (trip['to_longitude']! as num).toDouble(),
      );
      final addedMetres = previous.distanceTo(point).round();
      if (addedMetres < 10) return;
      await txn.update(
        'trip_log',
        {
          'arrived_at': nextAt.toIso8601String(),
          'to_latitude': point.latitude,
          'to_longitude': point.longitude,
          'distance_metres': (trip['distance_metres']! as int) + addedMetres,
          'duration_seconds': nextAt
              .difference(DateTime.parse(trip['departed_at']! as String))
              .inSeconds,
          'distance_source': 'gps',
        },
        where: 'id = ?',
        whereArgs: [tripId],
      );
    });
  }

  Future<void> finishGpsTrip(int tripId) async {
    await _db.transaction((txn) async {
      await txn.update(
        'trip_settings',
        {'active_gps_trip_id': null},
        where: 'id = 1 AND active_gps_trip_id = ?',
        whereArgs: [tripId],
      );
    });
  }

  Future<void> clearActiveGpsTrip() async {
    await _db.update('trip_settings', {
      'active_gps_trip_id': null,
    }, where: 'id = 1');
  }

  Future<void> classify(
    int id, {
    required bool business,
    required String purpose,
  }) async {
    await _db.update(
      'trip_log',
      {
        'business': business ? 1 : 0,
        'classified': 1,
        'purpose': purpose.trim(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
