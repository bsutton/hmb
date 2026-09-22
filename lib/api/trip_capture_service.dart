import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../dao/dao_system.dart';
import '../dao/dao_trip_log.dart';
import '../database/management/database_helper.dart';
import '../entity/trip_log.dart';

/// One foreground fix per resume; no timer, background service or tracking.
class TripCaptureService {
  static final instance = TripCaptureService();
  // Cancelled after the first fix, timeout, pause or app disposal.
  // ignore: cancel_subscriptions
  StreamSubscription<Position>? _positions;
  Completer<Position?>? _fix;
  var _busy = false;
  final status = ValueNotifier<String>('Trip logging is off');

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> requestPermission() async {
    if (!supported) {
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> cancelFix() async {
    final pending = _fix;
    final positions = _positions;
    _fix = null;
    _positions = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(null);
    }
    await positions?.cancel();
  }

  Future<TripPoint?> currentPoint() async {
    if (!supported ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        !await Geolocator.isLocationServiceEnabled()) {
      return null;
    }
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }
    await cancelFix();
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return null;
    }
    final fix = Completer<Position?>();
    _fix = fix;
    _positions =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).listen(
          (position) {
            if (!fix.isCompleted &&
                position.accuracy <= 100 &&
                DateTime.now().difference(position.timestamp).abs() <=
                    const Duration(minutes: 2)) {
              fix.complete(position);
            }
          },
          onError: (Object _) {
            if (!fix.isCompleted) {
              fix.complete(null);
            }
          },
        );
    try {
      final position = await fix.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      );
      if (position == null ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return null;
      }
      return TripPoint(position.latitude, position.longitude);
    } finally {
      if (identical(_fix, fix)) {
        await cancelFix();
      }
    }
  }

  Future<void> onResume() async {
    if (_busy || !supported) {
      return;
    }
    _busy = true;
    try {
      if (!await DatabaseHelper().waitUntilOpen()) {
        return;
      }
      final settings = await DaoTripLog().settings();
      if (!settings.enabled) {
        status.value = 'Trip logging is off';
        return;
      }
      final point = await currentPoint();
      if (point != null) {
        await DaoTripLog().observe(point, DateTime.now());
        status.value = 'Location checked';
      } else {
        status.value = 'No location fix. Check location permission and GPS.';
      }
      await updateRoutes();
    } catch (_) {
      // Do not log coordinates, raw API responses or credentials.
      status.value = 'Trip check failed. Reopen the app to retry.';
    } finally {
      _busy = false;
    }
  }

  Future<void> updateRoutes() async {
    final settings = await DaoTripLog().settings();
    if (!settings.enabled || !settings.routeLookupEnabled) {
      return;
    }
    final key = (await DaoSystem().getGoogleMapsCredentials()).apiKey;
    if (key == null || key.isEmpty) {
      status.value = 'Set up Google Maps to calculate road distances.';
      return;
    }
    final client = http.Client();
    try {
      for (final trip in await DaoTripLog().pendingRoutes()) {
        final current = await DaoTripLog().settings();
        if (!current.enabled || !current.routeLookupEnabled) {
          return;
        }
        final route = await TripRouteClient(
          client,
        ).distance(trip.from, trip.to, key);
        await DaoTripLog().saveRoute(trip, route.$1, route.$2);
      }
    } finally {
      client.close();
    }
  }
}

class TripRouteClient {
  final http.Client client;
  TripRouteClient(this.client);

  /// https://developers.google.com/maps/documentation/routes/compute_route_directions
  Future<(int, int)> distance(TripPoint from, TripPoint to, String key) async {
    Map<String, Object> waypoint(TripPoint point) => {
      'location': {
        'latLng': {'latitude': point.latitude, 'longitude': point.longitude},
      },
    };
    final response = await client
        .post(
          Uri.parse(
            'https://routes.googleapis.com/directions/v2:computeRoutes',
          ),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': key,
            'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration',
          },
          body: jsonEncode({
            'origin': waypoint(from),
            'destination': waypoint(to),
            'travelMode': 'DRIVE',
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Route lookup failed');
    }
    final routes =
        (jsonDecode(response.body) as Map<String, dynamic>)['routes']
            as List<dynamic>;
    if (routes.isEmpty) {
      throw StateError('No driving route found');
    }
    final route = routes.first as Map<String, dynamic>;
    final metres = (route['distanceMeters'] as num).toInt();
    final seconds = double.parse(
      (route['duration'] as String).replaceFirst(RegExp(r's$'), ''),
    ).round();
    if (metres < 0 || seconds < 0) {
      throw StateError('Invalid route');
    }
    return (metres, seconds);
  }
}
