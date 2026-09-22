import 'dart:math' as math;

class TripPoint {
  final double latitude;
  final double longitude;

  const TripPoint(this.latitude, this.longitude);

  bool get valid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  double distanceTo(TripPoint other) {
    const radians = math.pi / 180;
    final lat = (other.latitude - latitude) * radians;
    final lon = (other.longitude - longitude) * radians;
    final a =
        math.pow(math.sin(lat / 2), 2) +
        math.cos(latitude * radians) *
            math.cos(other.latitude * radians) *
            math.pow(math.sin(lon / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}

class TripSettings {
  final bool enabled;
  final bool routeLookupEnabled;
  final TripPoint? home;
  final String homeLabel;
  final int rateCentsPerKm;

  const TripSettings({
    this.enabled = false,
    this.routeLookupEnabled = false,
    this.home,
    this.homeLabel = 'Home',
    this.rateCentsPerKm = 0,
  });

  factory TripSettings.fromMap(Map<String, Object?> row) => TripSettings(
    enabled: row['enabled'] == 1,
    routeLookupEnabled: row['route_lookup_enabled'] == 1,
    home: row['home_latitude'] == null || row['home_longitude'] == null
        ? null
        : TripPoint(
            (row['home_latitude']! as num).toDouble(),
            (row['home_longitude']! as num).toDouble(),
          ),
    homeLabel: row['home_label'] as String? ?? 'Home',
    rateCentsPerKm: row['rate_cents_per_km'] as int? ?? 0,
  );

  Map<String, Object?> toMap() => {
    'id': 1,
    'enabled': enabled ? 1 : 0,
    'route_lookup_enabled': routeLookupEnabled ? 1 : 0,
    'home_latitude': home?.latitude,
    'home_longitude': home?.longitude,
    'home_label': homeLabel,
    'rate_cents_per_km': rateCentsPerKm,
  };
}

class TripLog {
  final int id;
  final DateTime? departedAt;
  final DateTime arrivedAt;
  final TripPoint from;
  final TripPoint to;
  final bool fromHome;
  final int? distanceMetres;
  final int? durationSeconds;
  final int? siteId;
  final int? jobId;
  final String purpose;
  final bool business;

  TripLog.fromMap(Map<String, Object?> row)
    : id = row['id']! as int,
      departedAt = DateTime.tryParse(
        row['departed_at'] as String? ?? '',
      )?.toLocal(),
      arrivedAt = DateTime.parse(row['arrived_at']! as String).toLocal(),
      from = TripPoint(
        (row['from_latitude']! as num).toDouble(),
        (row['from_longitude']! as num).toDouble(),
      ),
      to = TripPoint(
        (row['to_latitude']! as num).toDouble(),
        (row['to_longitude']! as num).toDouble(),
      ),
      fromHome = row['from_home'] == 1,
      distanceMetres = row['distance_metres'] as int?,
      durationSeconds = row['duration_seconds'] as int?,
      siteId = row['site_id'] as int?,
      jobId = row['job_id'] as int?,
      purpose = row['purpose'] as String? ?? '',
      business = row['business'] == 1;
}
