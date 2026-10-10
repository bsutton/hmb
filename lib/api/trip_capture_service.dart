import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../dao/dao_system.dart';
import '../dao/dao_trip_log.dart';
import '../database/management/database_helper.dart';
import '../entity/trip_log.dart';

enum NavigationTrackingResult {
  disabled,
  started,
  alreadyTracking,
  permissionDenied,
  locationDisabled,
  noLocationFix,
}

/// Captures a foreground fix on resume and optional GPS navigation sessions.
class TripCaptureService {
  static final instance = TripCaptureService();
  // Cancelled after the first fix, timeout, pause or app disposal.
  // ignore: cancel_subscriptions
  StreamSubscription<Position>? _fixPositions;
  StreamSubscription<Position>? _gpsPositions;
  Completer<Position?>? _fix;
  var _busy = false;
  int? _activeGpsTripId;
  int? _gpsSiteId;
  int? _gpsJobId;
  Future<void> _gpsUpdateTail = Future<void>.value();
  final status = ValueNotifier<String>('Trip logging is off');
  final isGpsTracking = ValueNotifier<bool>(false);

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<LocationPermission> requestPermission() async {
    if (!supported) {
      return LocationPermission.denied;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<bool> _requestBackgroundPermission() async {
    final foreground = await Permission.locationWhenInUse.request();
    if (!foreground.isGranted) {
      return false;
    }
    final background = await Permission.locationAlways.status;
    if (background.isGranted) {
      return true;
    }
    return (await Permission.locationAlways.request()).isGranted;
  }

  Future<bool> requestGpsBackgroundPermission() =>
      _requestBackgroundPermission();

  Future<String> locationUnavailableMessage() async {
    if (!supported) {
      return 'Automatic trip capture is available on Android and iOS.';
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Device location is off. Turn it on to capture trips.';
    }
    return switch (await Geolocator.checkPermission()) {
      LocationPermission.denied =>
        'Location access is off. Allow it to capture trips.',
      LocationPermission.deniedForever =>
        'Location access is blocked. Allow it for HMB in app settings.',
      LocationPermission.whileInUse || LocationPermission.always =>
        'No location fix. Check the device GPS and try again.',
      LocationPermission.unableToDetermine =>
        'Location permission could not be checked. Try again.',
    };
  }

  Future<void> cancelFix() async {
    final pending = _fix;
    final positions = _fixPositions;
    _fix = null;
    _fixPositions = null;
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
    _fixPositions =
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

  Future<NavigationTrackingResult> startGpsTrackingFromNavigation({
    int? siteId,
    int? jobId,
  }) async {
    if (!supported) {
      status.value = 'GPS trip tracking is available on Android and iOS.';
      return NavigationTrackingResult.disabled;
    }
    if (!await DatabaseHelper().waitUntilOpen()) {
      return NavigationTrackingResult.disabled;
    }
    final settings = await DaoTripLog().settings();
    if (!settings.enabled || !settings.gpsTrackingEnabled) {
      return NavigationTrackingResult.disabled;
    }
    if (_gpsPositions != null || _activeGpsTripId != null) {
      return NavigationTrackingResult.alreadyTracking;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      status.value = 'Device location is off. Turn it on to track this trip.';
      return NavigationTrackingResult.locationDisabled;
    }
    if (!await _requestBackgroundPermission()) {
      status.value =
          'Allow background location for HMB to track trips during navigation.';
      return NavigationTrackingResult.permissionDenied;
    }

    _gpsSiteId = siteId;
    _gpsJobId = jobId;
    _gpsPositions =
        Geolocator.getPositionStream(
          locationSettings: _gpsLocationSettings(),
        ).listen(
          _queueGpsPosition,
          onError: (Object _) {
            status.value = 'GPS tracking stopped receiving location updates.';
          },
        );
    isGpsTracking.value = true;
    status.value = 'GPS trip tracking is active.';
    return NavigationTrackingResult.started;
  }

  Future<void> restoreGpsTracking() async {
    if (!supported || _gpsPositions != null) {
      return;
    }
    if (!await DatabaseHelper().waitUntilOpen()) {
      return;
    }
    final settings = await DaoTripLog().settings();
    final tripId = settings.activeGpsTripId;
    if (!settings.enabled || !settings.gpsTrackingEnabled || tripId == null) {
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled() ||
        !(await Permission.locationAlways.status).isGranted) {
      return;
    }
    _activeGpsTripId = tripId;
    _gpsPositions = Geolocator.getPositionStream(
      locationSettings: _gpsLocationSettings(),
    ).listen(_queueGpsPosition);
    isGpsTracking.value = true;
    status.value = 'GPS trip tracking is active.';
  }

  LocationSettings _gpsLocationSettings() => switch (defaultTargetPlatform) {
    TargetPlatform.android => AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
      intervalDuration: const Duration(seconds: 10),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'HMB trip tracking',
        notificationText: 'Recording GPS distance for your active trip',
        notificationChannelName: 'Trip tracking',
        enableWakeLock: true,
        setOngoing: true,
      ),
    ),
    TargetPlatform.iOS => AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: 25,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
    ),
    _ => const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    ),
  };

  void _queueGpsPosition(Position position) {
    _gpsUpdateTail = _gpsUpdateTail
        .catchError((Object _) {})
        .then((_) => _recordGpsPosition(position));
  }

  Future<void> _recordGpsPosition(Position position) async {
    if (position.accuracy > 50 ||
        DateTime.now().difference(position.timestamp).abs() >
            const Duration(minutes: 2)) {
      return;
    }
    final point = TripPoint(position.latitude, position.longitude);
    if (!point.valid) {
      return;
    }
    _activeGpsTripId ??= await DaoTripLog().startGpsTrip(
      point,
      position.timestamp,
      siteId: _gpsSiteId,
      jobId: _gpsJobId,
    );
    final tripId = _activeGpsTripId;
    if (tripId != null) {
      await DaoTripLog().recordGpsPosition(tripId, point, position.timestamp);
    }
  }

  Future<void> stopGpsTracking() async {
    final subscription = _gpsPositions;
    _gpsPositions = null;
    await subscription?.cancel();
    await _gpsUpdateTail;
    final tripId = _activeGpsTripId;
    if (tripId != null) {
      await DaoTripLog().finishGpsTrip(tripId);
    } else if (await DatabaseHelper().waitUntilOpen()) {
      await DaoTripLog().clearActiveGpsTrip();
    }
    _activeGpsTripId = null;
    _gpsSiteId = null;
    _gpsJobId = null;
    isGpsTracking.value = false;
    status.value = 'GPS trip tracking stopped.';
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
      await restoreGpsTracking();
      if (!settings.enabled) {
        status.value = 'Trip logging is off';
        return;
      }
      final point = await currentPoint();
      if (point != null) {
        final originAddress = await _configuredOriginAddress(settings);
        await DaoTripLog().observe(
          point,
          DateTime.now(),
          originAddress: originAddress,
        );
        status.value = 'Location checked';
      } else {
        status.value = await locationUnavailableMessage();
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
    var failed = 0;
    try {
      int? afterId;
      while (true) {
        final pending = await DaoTripLog().pendingRoutes(afterId: afterId);
        if (pending.isEmpty) {
          break;
        }
        for (final trip in pending) {
          afterId = trip.id;
          final current = await DaoTripLog().settings();
          if (!current.enabled || !current.routeLookupEnabled) {
            return;
          }
          try {
            final route = await TripRouteClient(
              client,
            ).distanceFromTrip(trip, key);
            await DaoTripLog().saveRoute(trip, route.$1, route.$2);
          } catch (_) {
            // Keep this trip pending and continue with other route requests.
            failed++;
          }
        }
      }
      status.value = failed == 0
          ? 'Road distances updated.'
          : '$failed road distance(s) could not be calculated. '
                'Check Maps setup and retry.';
    } finally {
      client.close();
    }
  }

  Future<String?> _configuredOriginAddress(TripSettings settings) async {
    if (settings.originType == TripOriginType.alternateAddress) {
      return settings.alternateOriginAddress.trim();
    }
    return (await DaoSystem().get()).address.trim();
  }
}

class TripRouteClient {
  final http.Client client;
  TripRouteClient(this.client);

  /// https://developers.google.com/maps/documentation/routes/compute_route_directions
  Future<(int, int)> distance(TripPoint from, TripPoint to, String key) {
    Map<String, Object> waypoint(TripPoint point) => {
      'location': {
        'latLng': {'latitude': point.latitude, 'longitude': point.longitude},
      },
    };
    return _distance(waypoint(from), waypoint(to), key);
  }

  Future<(int, int)> distanceFromTrip(TripLog trip, String key) {
    final origin = trip.fromAddress?.trim();
    if (origin != null && origin.isNotEmpty) {
      return _distance({'address': origin}, _waypoint(trip.to), key);
    }
    return distance(trip.from, trip.to, key);
  }

  Map<String, Object> _waypoint(TripPoint point) => {
    'location': {
      'latLng': {'latitude': point.latitude, 'longitude': point.longitude},
    },
  };

  Future<(int, int)> _distance(
    Map<String, Object> origin,
    Map<String, Object> destination,
    String key,
  ) async {
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
            'origin': origin,
            'destination': destination,
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
