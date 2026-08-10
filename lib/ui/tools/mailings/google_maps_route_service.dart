/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../dao/dao_site.dart';
import '../../../dao/dao_system.dart';
import '../../../entity/mailing_recipient.dart';
import '../../../entity/site.dart';

class RouteOptimisationResult {
  final List<MailingRecipient> recipients;
  final String? fallbackReason;
  final MailingRecipient? failedRecipient;

  const RouteOptimisationResult({
    required this.recipients,
    this.fallbackReason,
    this.failedRecipient,
  });

  bool get usedGoogleOptimisation => fallbackReason == null;
}

class MailingAddressValidationIssue {
  final MailingRecipient? recipient;
  final String message;
  final List<SuggestedSiteAddress> suggestions;
  final String? suggestionFailure;

  MailingAddressValidationIssue({
    required this.message,
    this.recipient,
    SuggestedSiteAddress? suggestion,
    List<SuggestedSiteAddress> suggestions = const [],
    this.suggestionFailure,
  }) : suggestions = suggestions.isNotEmpty
           ? suggestions
           : suggestion == null
           ? const []
           : [suggestion];

  SuggestedSiteAddress? get suggestion =>
      suggestions.isEmpty ? null : suggestions.first;
}

class SuggestedSiteAddress {
  final Site site;
  final String formattedAddress;

  const SuggestedSiteAddress({
    required this.site,
    required this.formattedAddress,
  });
}

class _AddressSuggestionLookup {
  final List<SuggestedSiteAddress> suggestions;
  final String? failure;
  final bool stopValidation;
  final bool accepted;

  const _AddressSuggestionLookup({
    this.suggestions = const [],
    this.failure,
    this.stopValidation = false,
    this.accepted = false,
  });

  SuggestedSiteAddress? get suggestion =>
      suggestions.isEmpty ? null : suggestions.first;
}

class _LatLng {
  final double latitude;
  final double longitude;

  const _LatLng(this.latitude, this.longitude);
}

class _RoutePoint {
  final MailingRecipient recipient;
  final _LatLng location;

  const _RoutePoint({required this.recipient, required this.location});
}

class _RouteCheckResult {
  final bool routeable;
  final String? failure;

  const _RouteCheckResult._({required this.routeable, this.failure});

  const _RouteCheckResult.routeable() : this._(routeable: true);

  const _RouteCheckResult.notRouteable() : this._(routeable: false);

  const _RouteCheckResult.failed(String failure)
    : this._(routeable: false, failure: failure);

  bool get failed => failure != null;
}

class _ChunkRouteCandidate {
  final List<MailingRecipient> recipients;
  final int? distanceMeters;

  const _ChunkRouteCandidate({
    required this.recipients,
    required this.distanceMeters,
  });
}

class _PlacesSuggestionLookup {
  final List<SuggestedSiteAddress> suggestions;
  final String? failure;
  final bool stopValidation;

  const _PlacesSuggestionLookup({
    this.suggestions = const [],
    this.failure,
    this.stopValidation = false,
  });
}

class GoogleMapsRouteService {
  static const _requestTimeout = Duration(seconds: 8);
  static const _optimisedRouteFieldMask =
      'routes.optimizedIntermediateWaypointIndex,routes.distanceMeters,'
      'geocodingResults';
  static const _routeExistsFieldMask = 'routes.distanceMeters';

  final http.Client _client;
  final Future<String?> Function() _apiKeyProvider;

  GoogleMapsRouteService({
    http.Client? client,
    Future<String?> Function()? apiKeyProvider,
  }) : _client = client ?? http.Client(),
       _apiKeyProvider =
           apiKeyProvider ??
           (() async => (await DaoSystem().getGoogleMapsCredentials()).apiKey);

  Future<List<MailingRecipient>> optimise({
    required String origin,
    required List<MailingRecipient> recipients,
  }) async => (await optimiseWithResult(
    origin: origin,
    recipients: recipients,
  )).recipients;

  Future<RouteOptimisationResult> optimiseWithResult({
    required String origin,
    required List<MailingRecipient> recipients,
  }) async {
    final apiKey = (await _apiKeyProvider())?.trim();
    final routeable = recipients
        .where((recipient) => recipient.hasAddress && !recipient.excluded)
        .toList();
    if (routeable.length < 2) {
      return RouteOptimisationResult(recipients: routeable);
    }
    if (apiKey == null || apiKey.isEmpty) {
      return _failedResult(routeable, 'Google Maps API key is not configured.');
    }

    final originLocation = routeable.length > 2
        ? await _addressLocation(origin, apiKey)
        : null;
    final routeOrder = await _preorderForChunking(
      origin: origin,
      routeable: routeable,
      apiKey: apiKey,
      originLocation: originLocation,
    );
    final ordered = <MailingRecipient>[];
    String? fallbackReason;
    MailingRecipient? failedRecipient;
    var chunkOrigin = origin;
    var chunkOriginLocation = originLocation;
    for (var start = 0; start < routeOrder.length; start += 25) {
      final chunk = routeOrder.skip(start).take(25).toList();
      final result = await _optimiseChunk(
        chunkOrigin,
        chunk,
        apiKey,
        originLocation: chunkOriginLocation,
        validationOrigin: origin,
      );
      ordered.addAll(result.recipients);
      if (result.fallbackReason != null) {
        fallbackReason = result.fallbackReason;
        failedRecipient = result.failedRecipient;
        break;
      }
      if (result.recipients.isNotEmpty) {
        final last = result.recipients.last;
        chunkOrigin = last.address;
        chunkOriginLocation = await _recipientLocation(last);
      }
    }
    return RouteOptimisationResult(
      recipients: ordered,
      fallbackReason: fallbackReason,
      failedRecipient: failedRecipient,
    );
  }

  Future<List<MailingAddressValidationIssue>> validateRecipients({
    required List<MailingRecipient> recipients,
    String? businessAddress,
    bool checkRouteReadiness = false,
  }) async {
    final apiKey = (await _apiKeyProvider())?.trim();
    final candidates = recipients
        .where((recipient) => !recipient.excluded)
        .toList();
    if (candidates.isEmpty) {
      return const [];
    }
    if (apiKey == null || apiKey.isEmpty) {
      return [
        MailingAddressValidationIssue(
          message: 'Google Maps API key is not configured.',
        ),
      ];
    }

    final issues = <MailingAddressValidationIssue>[];
    var businessBiasLoaded = false;
    _LatLng? businessBias;
    Future<_LatLng?> businessBiasProvider() async {
      if (businessBiasLoaded) {
        return businessBias;
      }
      businessBiasLoaded = true;
      final address = businessAddress?.trim();
      if (address == null || address.isEmpty) {
        return null;
      }
      final location = await _addressLocation(address, apiKey);
      businessBias = location;
      return location;
    }

    final hasBusinessAddress = businessAddress?.trim().isNotEmpty ?? false;
    for (final recipient in candidates) {
      final site = await _siteForRecipient(recipient);
      if (site == null) {
        issues.add(
          MailingAddressValidationIssue(
            recipient: recipient,
            suggestionFailure:
                'No editable site address is linked to this recipient.',
            message:
                'Could not validate ${recipient.contactName}: '
                '${recipient.address}.',
          ),
        );
        continue;
      }
      final validationSite = _siteForValidation(site);
      final displayAddress = validationSite.address;
      if (displayAddress.trim().isEmpty) {
        issues.add(
          MailingAddressValidationIssue(
            recipient: recipient,
            suggestionFailure: 'No usable address is available.',
            message:
                'Could not validate ${recipient.contactName}: '
                'no usable address is available.',
          ),
        );
        continue;
      }
      if (!_hasSpecificSiteAddress(validationSite)) {
        await DaoSite().update(
          site.copyWith(clearGeocode: true, geocodeStatus: 'invalid'),
        );
        issues.add(
          MailingAddressValidationIssue(
            recipient: recipient,
            suggestionFailure:
                'Address must include a street number and suburb.',
            message:
                'Could not validate ${recipient.contactName}: '
                '$displayAddress.',
          ),
        );
        continue;
      }
      if (site.geocodeStatus == 'route_failed') {
        if (checkRouteReadiness) {
          final suggestion = await _suggestSiteAddress(
            validationSite,
            placeBiasProvider: hasBusinessAddress ? businessBiasProvider : null,
          );
          final usefulSuggestions = suggestion.suggestions
              .where(
                (candidate) => _addressNeedsAttention(site, candidate.site),
              )
              .toList();
          issues.add(
            MailingAddressValidationIssue(
              recipient: recipient,
              suggestions: usefulSuggestions,
              suggestionFailure: usefulSuggestions.isEmpty
                  ? suggestion.failure ??
                        'This address cannot be used as a delivery route stop. '
                            'Check the street, unit, and suburb before routing.'
                  : null,
              message:
                  'Route planning needs attention for '
                  '${recipient.contactName}: $displayAddress.',
            ),
          );
          continue;
        }
        if (site.latitude != null && site.longitude != null) {
          continue;
        }
      }
      if (_hasValidatedGeocode(site)) {
        continue;
      }

      final shouldCheckRoute =
          checkRouteReadiness && site.geocodeStatus == 'invalidated';
      final suggestion = await _suggestSiteAddress(
        validationSite,
        placeBiasProvider: hasBusinessAddress ? businessBiasProvider : null,
      );
      final suggestedAddress = suggestion.suggestion;
      if (suggestedAddress == null) {
        issues.add(
          MailingAddressValidationIssue(
            recipient: suggestion.stopValidation ? null : recipient,
            suggestionFailure: suggestion.failure,
            message: suggestion.stopValidation
                ? 'Address validation stopped.'
                : 'Could not validate ${recipient.contactName}: '
                      '$displayAddress.',
          ),
        );
        if (suggestion.stopValidation) {
          break;
        }
        continue;
      }
      if (!suggestion.accepted ||
          _addressNeedsAttention(site, suggestedAddress.site)) {
        await DaoSite().update(
          site.copyWith(clearGeocode: true, geocodeStatus: 'invalid'),
        );
        issues.add(
          MailingAddressValidationIssue(
            recipient: recipient,
            suggestions: suggestion.suggestions,
            message:
                'Address may need attention for ${recipient.contactName}: '
                '$displayAddress.',
          ),
        );
        continue;
      }
      if (shouldCheckRoute && (businessAddress?.trim().isNotEmpty ?? false)) {
        final routeCheck = await _canUseAddressAsDeliveryWaypoint(
          businessAddress!.trim(),
          suggestedAddress.site.address,
          apiKey,
        );
        if (routeCheck.failed) {
          issues.add(
            MailingAddressValidationIssue(
              suggestionFailure: routeCheck.failure,
              message: 'Route readiness check stopped.',
            ),
          );
          break;
        }
        if (!routeCheck.routeable) {
          await DaoSite().update(
            suggestedAddress.site.copyWith(geocodeStatus: 'route_failed'),
          );
          issues.add(
            MailingAddressValidationIssue(
              recipient: recipient,
              suggestionFailure:
                  'This address cannot be used as a delivery route stop. '
                  'Check the street, unit, and suburb before routing.',
              message:
                  'Route planning needs attention for '
                  '${recipient.contactName}: '
                  '${suggestedAddress.site.address}.',
            ),
          );
          continue;
        }
      }
      await DaoSite().update(
        site.copyWith(
          latitude: suggestedAddress.site.latitude,
          longitude: suggestedAddress.site.longitude,
          geocodeStatus: shouldCheckRoute ? 'route_ok' : 'ok',
          geocodedAt: DateTime.now(),
        ),
      );
    }
    return issues;
  }

  Site _siteForValidation(Site site) {
    final name = site.name?.trim() ?? '';
    if (site.addressLine1.trim().isEmpty && name.isNotEmpty) {
      return site.copyWith(addressLine1: name);
    }
    return site;
  }

  Future<Site?> _siteForRecipient(MailingRecipient recipient) async {
    final siteId = recipient.siteId;
    if (siteId != null) {
      return DaoSite().getById(siteId);
    }
    final sites = await DaoSite().getByCustomer(recipient.customerId);
    if (sites.length == 1) {
      return sites.single;
    }
    return null;
  }

  Future<List<MailingRecipient>> _preorderForChunking({
    required String origin,
    required List<MailingRecipient> routeable,
    required String apiKey,
    _LatLng? originLocation,
  }) async {
    if (routeable.length <= 25) {
      return routeable;
    }
    final points = <_RoutePoint>[];
    final withoutGeocode = <MailingRecipient>[];
    for (final recipient in routeable) {
      final site = await _siteForRecipient(recipient);
      final latitude = site?.latitude;
      final longitude = site?.longitude;
      if (site != null &&
          _hasValidatedGeocode(site) &&
          latitude != null &&
          longitude != null) {
        points.add(
          _RoutePoint(
            recipient: recipient,
            location: _LatLng(latitude, longitude),
          ),
        );
      } else {
        withoutGeocode.add(recipient);
      }
    }
    if (points.length < 2) {
      return routeable;
    }

    final startLocation =
        originLocation ??
        await _addressLocation(origin, apiKey) ??
        _centroid(points);
    final orderedPoints = _twoOpt(
      _nearestNeighbourOrder(points, startLocation),
      startLocation,
    );
    return [
      for (final point in orderedPoints) point.recipient,
      ..._fallbackOrder(withoutGeocode),
    ];
  }

  Future<_LatLng?> _addressLocation(String address, String apiKey) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.https(
      'addressvalidation.googleapis.com',
      '/v1:validateAddress',
      {'key': apiKey},
    );
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'address': {
                'regionCode': 'AU',
                'addressLines': [trimmed],
              },
            }),
          )
          .timeout(_requestTimeout);
    } catch (_) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final decoded = _decodeGoogleResponse(response);
    final result = decoded?['result'] as Map<String, dynamic>?;
    final location =
        (result?['geocode'] as Map<String, dynamic>?)?['location']
            as Map<String, dynamic>?;
    final latitude = (location?['latitude'] as num?)?.toDouble();
    final longitude = (location?['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      return null;
    }
    return _LatLng(latitude, longitude);
  }

  Future<_LatLng?> _recipientLocation(MailingRecipient recipient) async {
    final site = await _siteForRecipient(recipient);
    final latitude = site?.latitude;
    final longitude = site?.longitude;
    if (site == null ||
        !_hasValidatedGeocode(site) ||
        latitude == null ||
        longitude == null) {
      return null;
    }
    return _LatLng(latitude, longitude);
  }

  Future<List<MailingRecipient>> _destinationCandidates({
    required List<MailingRecipient> routeable,
    required _LatLng? originLocation,
  }) async {
    if (routeable.length <= 2) {
      return [routeable.last];
    }
    final candidates = <MailingRecipient>[];
    void add(MailingRecipient recipient) {
      if (!candidates.any((candidate) => candidate.id == recipient.id)) {
        candidates.add(recipient);
      }
    }

    add(routeable.last);
    final points = <_RoutePoint>[];
    for (final recipient in routeable) {
      final location = await _recipientLocation(recipient);
      if (location != null) {
        points.add(_RoutePoint(recipient: recipient, location: location));
      }
    }
    if (points.isEmpty) {
      return candidates;
    }

    final startLocation = originLocation ?? _centroid(points);
    add(_farthestPoint(points, startLocation).recipient);
    if (points.length > 2) {
      add(_farthestPoint(points, _centroid(points)).recipient);
    }
    return candidates.take(3).toList();
  }

  _RoutePoint _farthestPoint(List<_RoutePoint> points, _LatLng location) {
    var farthest = points.first;
    var farthestDistance = _distance(location, farthest.location);
    for (final point in points.skip(1)) {
      final distance = _distance(location, point.location);
      if (distance > farthestDistance) {
        farthest = point;
        farthestDistance = distance;
      }
    }
    return farthest;
  }

  _LatLng _centroid(List<_RoutePoint> points) {
    final latitude =
        points.map((point) => point.location.latitude).reduce((a, b) => a + b) /
        points.length;
    final longitude =
        points
            .map((point) => point.location.longitude)
            .reduce((a, b) => a + b) /
        points.length;
    return _LatLng(latitude, longitude);
  }

  List<_RoutePoint> _nearestNeighbourOrder(
    List<_RoutePoint> points,
    _LatLng origin,
  ) {
    final remaining = [...points];
    final ordered = <_RoutePoint>[];
    var current = origin;
    while (remaining.isNotEmpty) {
      var nearestIndex = 0;
      var nearestDistance = _distance(current, remaining.first.location);
      for (var index = 1; index < remaining.length; index++) {
        final distance = _distance(current, remaining[index].location);
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestIndex = index;
        }
      }
      final nearest = remaining.removeAt(nearestIndex);
      ordered.add(nearest);
      current = nearest.location;
    }
    return ordered;
  }

  List<_RoutePoint> _twoOpt(List<_RoutePoint> route, _LatLng origin) {
    if (route.length < 4) {
      return route;
    }
    final improved = [...route];
    var changed = true;
    var passes = 0;
    while (changed && passes < 8) {
      changed = false;
      passes++;
      for (var i = 0; i < improved.length - 2; i++) {
        for (var k = i + 1; k < improved.length - 1; k++) {
          final before = _routeSegmentDistance(improved, origin, i, k);
          final candidate = [
            ...improved.take(i),
            ...improved.sublist(i, k + 1).reversed,
            ...improved.skip(k + 1),
          ];
          final after = _routeSegmentDistance(candidate, origin, i, k);
          if (after + 0.000001 < before) {
            improved
              ..clear()
              ..addAll(candidate);
            changed = true;
          }
        }
      }
    }
    return improved;
  }

  double _routeSegmentDistance(
    List<_RoutePoint> route,
    _LatLng origin,
    int start,
    int end,
  ) {
    final fromBeforeStart = start == 0 ? origin : route[start - 1].location;
    final toAfterEnd = end + 1 >= route.length ? null : route[end + 1].location;
    var distance = _distance(fromBeforeStart, route[start].location);
    for (var index = start; index < end; index++) {
      distance += _distance(route[index].location, route[index + 1].location);
    }
    if (toAfterEnd != null) {
      distance += _distance(route[end].location, toAfterEnd);
    }
    return distance;
  }

  double _distance(_LatLng left, _LatLng right) {
    const earthRadiusMeters = 6371000;
    final leftLat = _radians(left.latitude);
    final rightLat = _radians(right.latitude);
    final deltaLat = _radians(right.latitude - left.latitude);
    final deltaLng = _radians(right.longitude - left.longitude);
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(leftLat) *
            math.cos(rightLat) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  Future<RouteOptimisationResult> _optimiseChunk(
    String origin,
    List<MailingRecipient> routeable,
    String apiKey, {
    required _LatLng? originLocation,
    required String validationOrigin,
  }) async {
    final candidates = await _destinationCandidates(
      routeable: routeable,
      originLocation: originLocation,
    );
    final uri = Uri.parse(
      'https://routes.googleapis.com/directions/v2:computeRoutes',
    );
    _ChunkRouteCandidate? best;
    for (final destination in candidates) {
      final intermediates = routeable
          .where((recipient) => recipient.id != destination.id)
          .toList();
      final body = {
        'origin': {'address': origin},
        'destination': {'address': destination.address},
        'intermediates': [
          for (final recipient in intermediates) {'address': recipient.address},
        ],
        'travelMode': 'DRIVE',
        if (intermediates.isNotEmpty) 'optimizeWaypointOrder': true,
      };

      late final http.Response response;
      try {
        response = await _postComputeRoutes(
          uri: uri,
          apiKey: apiKey,
          fieldMask: _optimisedRouteFieldMask,
          body: body,
        );
      } catch (_) {
        return _failedResult(routeable, 'Google route optimisation timed out.');
      }
      _debugRouteResponse(
        reason: 'optimise response',
        statusCode: response.statusCode,
        routeable: routeable,
        responseBody: response.body,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _failedResult(
          routeable,
          _googleErrorMessage(response, 'Google route optimisation failed.'),
        );
      }

      final decoded = _decodeGoogleResponse(response);
      if (decoded == null) {
        return _failedResult(
          routeable,
          'Google returned an unreadable route response.',
        );
      }
      final routes = decoded['routes'] as List<dynamic>? ?? [];
      if (routes.isEmpty) {
        continue;
      }
      final route = routes.first as Map<String, dynamic>;
      final candidate = _chunkRouteCandidate(
        destination: destination,
        intermediates: intermediates,
        route: route,
        responseBody: response.body,
      );
      if (candidate == null) {
        return _failedResult(
          routeable,
          'Google returned an incomplete route order.',
        );
      }
      if (best == null ||
          _candidateDistance(candidate) < _candidateDistance(best)) {
        best = candidate;
      }
    }

    if (best == null) {
      return _handleNoRoute(
        origin,
        routeable,
        apiKey,
        originLocation: originLocation,
        validationOrigin: validationOrigin,
      );
    }
    return RouteOptimisationResult(recipients: best.recipients);
  }

  _ChunkRouteCandidate? _chunkRouteCandidate({
    required MailingRecipient destination,
    required List<MailingRecipient> intermediates,
    required Map<String, dynamic> route,
    required String responseBody,
  }) {
    final distanceMeters = (route['distanceMeters'] as num?)?.toInt();
    if (intermediates.length <= 1) {
      return _ChunkRouteCandidate(
        recipients: [...intermediates, destination],
        distanceMeters: distanceMeters,
      );
    }
    final indexes =
        route['optimizedIntermediateWaypointIndex'] as List<dynamic>?;
    if (indexes == null || indexes.length != intermediates.length) {
      _debugRouteResponse(
        reason: 'incomplete route order',
        routeable: [...intermediates, destination],
        responseBody: responseBody,
      );
      return null;
    }
    for (final index in indexes) {
      if (index is! int || index < 0 || index >= intermediates.length) {
        _debugRouteResponse(
          reason: 'invalid route order index $index',
          routeable: [...intermediates, destination],
          responseBody: responseBody,
        );
        return null;
      }
    }
    return _ChunkRouteCandidate(
      recipients: [
        for (final index in indexes) intermediates[index as int],
        destination,
      ],
      distanceMeters: distanceMeters,
    );
  }

  int _candidateDistance(_ChunkRouteCandidate candidate) =>
      candidate.distanceMeters ?? 0x7fffffff;

  Future<RouteOptimisationResult> _handleNoRoute(
    String origin,
    List<MailingRecipient> routeable,
    String apiKey, {
    required _LatLng? originLocation,
    required String validationOrigin,
  }) async {
    if (routeable.length == 1) {
      final recipient = routeable.single;
      final routeCheck = await _canRouteToStop(origin, recipient, apiKey);
      if (routeCheck.routeable) {
        return RouteOptimisationResult(recipients: routeable);
      }
      if (routeCheck.failed) {
        return _failedResult(routeable, routeCheck.failure!);
      }
      if (validationOrigin != origin) {
        final validationRouteCheck = await _canRouteToStop(
          validationOrigin,
          recipient,
          apiKey,
        );
        if (validationRouteCheck.routeable) {
          return RouteOptimisationResult(recipients: routeable);
        }
        if (validationRouteCheck.failed) {
          return _failedResult(routeable, validationRouteCheck.failure!);
        }
      }
      await _markRecipientAddressInvalid(recipient);
      return _failedResult(
        routeable,
        'Could not route to ${recipient.contactName}: '
        '${recipient.address}.',
        failedRecipient: recipient,
      );
    }

    final middle = routeable.length ~/ 2;
    final left = await _optimiseChunk(
      origin,
      routeable.take(middle).toList(),
      apiKey,
      originLocation: originLocation,
      validationOrigin: validationOrigin,
    );
    final rightOrigin = left.recipients.isEmpty
        ? origin
        : left.recipients.last.address;
    final rightOriginLocation = left.recipients.isEmpty
        ? originLocation
        : await _recipientLocation(left.recipients.last);
    final right = await _optimiseChunk(
      rightOrigin,
      routeable.skip(middle).toList(),
      apiKey,
      originLocation: rightOriginLocation,
      validationOrigin: validationOrigin,
    );
    final failed = left.fallbackReason != null
        ? left
        : right.fallbackReason != null
        ? right
        : null;
    return RouteOptimisationResult(
      recipients: [...left.recipients, ...right.recipients],
      fallbackReason: failed?.fallbackReason,
      failedRecipient: failed?.failedRecipient,
    );
  }

  Future<_RouteCheckResult> _canRouteToStop(
    String origin,
    MailingRecipient recipient,
    String apiKey,
  ) => _canRouteToAddress(origin, recipient.address, apiKey);

  Future<_RouteCheckResult> _canRouteToAddress(
    String origin,
    String destination,
    String apiKey,
  ) async {
    final uri = Uri.parse(
      'https://routes.googleapis.com/directions/v2:computeRoutes',
    );
    final body = {
      'origin': {'address': origin},
      'destination': {'address': destination},
      'travelMode': 'DRIVE',
    };
    try {
      final response = await _postComputeRoutes(
        uri: uri,
        apiKey: apiKey,
        fieldMask: _routeExistsFieldMask,
        body: body,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _RouteCheckResult.failed(
          _googleErrorMessage(response, 'Google route readiness check failed.'),
        );
      }
      final decoded = _decodeGoogleResponse(response);
      if (decoded == null) {
        return const _RouteCheckResult.failed(
          'Google returned an unreadable route readiness response.',
        );
      }
      final routes = decoded['routes'] as List<dynamic>? ?? [];
      return routes.isEmpty
          ? const _RouteCheckResult.notRouteable()
          : const _RouteCheckResult.routeable();
    } catch (_) {
      return const _RouteCheckResult.failed(
        'Google route readiness check timed out.',
      );
    }
  }

  Future<_RouteCheckResult> _canUseAddressAsDeliveryWaypoint(
    String origin,
    String address,
    String apiKey,
  ) async {
    final uri = Uri.parse(
      'https://routes.googleapis.com/directions/v2:computeRoutes',
    );
    final body = {
      'origin': {'address': origin},
      'destination': {'address': origin},
      'intermediates': [
        {'address': address},
      ],
      'travelMode': 'DRIVE',
    };
    try {
      final response = await _postComputeRoutes(
        uri: uri,
        apiKey: apiKey,
        fieldMask: _routeExistsFieldMask,
        body: body,
      );
      _debugRouteResponse(
        reason: 'validation waypoint route response',
        statusCode: response.statusCode,
        routeable: const [],
        responseBody: response.body,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _RouteCheckResult.failed(
          _googleErrorMessage(response, 'Google route readiness check failed.'),
        );
      }
      final decoded = _decodeGoogleResponse(response);
      if (decoded == null) {
        return const _RouteCheckResult.failed(
          'Google returned an unreadable route readiness response.',
        );
      }
      final routes = decoded['routes'] as List<dynamic>? ?? [];
      return routes.isEmpty
          ? const _RouteCheckResult.notRouteable()
          : const _RouteCheckResult.routeable();
    } catch (_) {
      return const _RouteCheckResult.failed(
        'Google route readiness check timed out.',
      );
    }
  }

  Future<void> _markRecipientAddressInvalid(MailingRecipient recipient) async {
    final site = await _siteForRecipient(recipient);
    if (site == null) {
      return;
    }
    await DaoSite().update(
      site.copyWith(clearGeocode: true, geocodeStatus: 'route_failed'),
    );
  }

  bool _hasValidatedGeocode(Site site) =>
      _hasSpecificSiteAddress(site) &&
      (site.geocodeStatus == 'ok' || site.geocodeStatus == 'route_ok') &&
      site.latitude != null &&
      site.longitude != null;

  bool _hasSpecificSiteAddress(Site site) =>
      MailingRecipient.hasSpecificAddressLine(site.addressLine1) &&
      site.suburb.trim().isNotEmpty;

  Future<http.Response> _postComputeRoutes({
    required Uri uri,
    required String apiKey,
    required String fieldMask,
    required Map<String, Object?> body,
  }) => _client
      .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': fieldMask,
        },
        body: jsonEncode(body),
      )
      .timeout(_requestTimeout);

  Future<Site> geocodeSite(Site site) async {
    final lookup = await _suggestSiteAddress(site);
    final suggestion = lookup.suggestion;
    if (lookup.failure != null) {
      final failed = site.copyWith(geocodeStatus: 'failed');
      await DaoSite().update(failed);
      return failed;
    }
    if (suggestion == null) {
      final failed = site.copyWith(geocodeStatus: 'not_found');
      await DaoSite().update(failed);
      return failed;
    }
    final updated = suggestion.site.copyWith(
      geocodeStatus: lookup.accepted ? 'ok' : 'invalid',
      geocodedAt: DateTime.now(),
    );
    await DaoSite().update(updated);
    return updated;
  }

  Future<SuggestedSiteAddress?> suggestSiteAddress(Site site) async =>
      (await _suggestSiteAddress(site)).suggestion;

  Future<_AddressSuggestionLookup> _suggestSiteAddress(
    Site site, {
    Future<_LatLng?> Function()? placeBiasProvider,
  }) async {
    final apiKey = (await _apiKeyProvider())?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return const _AddressSuggestionLookup(
        failure: 'Google Maps API key is not configured.',
      );
    }
    if (site.isEmpty()) {
      return const _AddressSuggestionLookup(
        failure: 'No address is available.',
      );
    }
    final uri = Uri.https(
      'addressvalidation.googleapis.com',
      '/v1:validateAddress',
      {'key': apiKey},
    );
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(_addressValidationRequest(site)),
          )
          .timeout(_requestTimeout);
    } catch (_) {
      return const _AddressSuggestionLookup(
        failure: 'Google address validation request timed out.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _AddressSuggestionLookup(
        failure: _addressValidationFailureMessage(response),
        stopValidation: _isAddressValidationRateLimit(response),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>?;
    if (result == null) {
      return const _AddressSuggestionLookup(
        failure: 'Google did not return an address validation result.',
      );
    }
    final validatedSuggestion = _suggestionFromAddressValidationResult(
      site,
      result,
    );
    final accepted = _addressValidationAccepted(result);
    final suggestions = <SuggestedSiteAddress>[];
    final seen = <String>{};
    void addSuggestion(SuggestedSiteAddress suggestion) {
      if (seen.add(_normaliseAddressPart(suggestion.site.address))) {
        suggestions.add(suggestion);
      }
    }

    if (validatedSuggestion != null &&
        (accepted || _addressNeedsAttention(site, validatedSuggestion.site))) {
      addSuggestion(validatedSuggestion);
    }

    final shouldSearchPlaces =
        !accepted || site.geocodeStatus == 'route_failed';
    String? placesFailure;
    var placesStopValidation = false;
    if (shouldSearchPlaces) {
      final bias = placeBiasProvider == null ? null : await placeBiasProvider();
      final places = await _placeSuggestions(
        site,
        apiKey,
        placeBias: bias,
        existingKeys: seen,
      );
      placesFailure = places.failure;
      placesStopValidation = places.stopValidation;
      for (final suggestion in places.suggestions) {
        addSuggestion(suggestion);
      }
    }

    if (suggestions.isEmpty) {
      return _AddressSuggestionLookup(
        failure:
            placesFailure ??
            'Google did not return a usable address suggestion.',
        stopValidation: placesStopValidation,
      );
    }
    return _AddressSuggestionLookup(
      suggestions: suggestions,
      failure: placesFailure,
      stopValidation: placesStopValidation,
      accepted: accepted,
    );
  }

  Future<_PlacesSuggestionLookup> _placeSuggestions(
    Site site,
    String apiKey, {
    required Set<String> existingKeys,
    _LatLng? placeBias,
  }) async {
    final input = site.address.trim();
    if (input.isEmpty) {
      return const _PlacesSuggestionLookup();
    }
    final body = <String, Object>{
      'input': input,
      'includedRegionCodes': ['au'],
      'includeQueryPredictions': false,
      if (placeBias != null)
        'locationBias': {
          'circle': {
            'center': {
              'latitude': placeBias.latitude,
              'longitude': placeBias.longitude,
            },
            'radius': 50000.0,
          },
        },
    };
    final uri = Uri.https('places.googleapis.com', '/v1/places:autocomplete');
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } catch (_) {
      return const _PlacesSuggestionLookup(
        failure: 'Google Places address suggestion request timed out.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _PlacesSuggestionLookup(
        failure: _placesFailureMessage(response),
        stopValidation: _isGoogleRateLimit(response),
      );
    }

    final decoded = _decodeGoogleResponse(response);
    final rawSuggestions = decoded?['suggestions'] as List<dynamic>? ?? [];
    final suggestions = <SuggestedSiteAddress>[];
    final seen = {...existingKeys};
    for (final raw in rawSuggestions.take(5)) {
      final item = raw as Map<String, dynamic>;
      final prediction = item['placePrediction'] as Map<String, dynamic>?;
      final text =
          (prediction?['text'] as Map<String, dynamic>?)?['text'] as String?;
      final candidate = text?.trim();
      if (candidate == null || candidate.isEmpty) {
        continue;
      }
      final suggestion = await _validatePlaceCandidate(site, candidate, apiKey);
      if (suggestion == null) {
        continue;
      }
      if (seen.add(_normaliseAddressPart(suggestion.site.address))) {
        suggestions.add(suggestion);
      }
    }
    return _PlacesSuggestionLookup(suggestions: suggestions);
  }

  Future<SuggestedSiteAddress?> _validatePlaceCandidate(
    Site original,
    String candidate,
    String apiKey,
  ) async {
    final uri = Uri.https(
      'addressvalidation.googleapis.com',
      '/v1:validateAddress',
      {'key': apiKey},
    );
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'address': {
                'regionCode': 'AU',
                'addressLines': [candidate],
              },
            }),
          )
          .timeout(_requestTimeout);
    } catch (_) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final decoded = _decodeGoogleResponse(response);
    final result = decoded?['result'] as Map<String, dynamic>?;
    if (result == null) {
      return null;
    }
    return _suggestionFromAddressValidationResult(original, result);
  }

  Map<String, Object> _addressValidationRequest(Site site) {
    final addressLines = <String>[
      site.addressLine1.trim(),
      if (site.addressLine2.trim().isNotEmpty) site.addressLine2.trim(),
    ].where((line) => line.isNotEmpty).toList();
    final postalAddress = <String, Object>{
      'regionCode': 'AU',
      if (addressLines.isNotEmpty) 'addressLines': addressLines,
      if (site.suburb.trim().isNotEmpty) 'locality': site.suburb.trim(),
      if (site.state.trim().isNotEmpty) 'administrativeArea': site.state.trim(),
      if (site.postcode.trim().isNotEmpty) 'postalCode': site.postcode.trim(),
    };
    return {'address': postalAddress};
  }

  bool _addressValidationAccepted(Map<String, dynamic> result) {
    final verdict = result['verdict'] as Map<String, dynamic>? ?? {};
    final validationGranularity =
        verdict['validationGranularity'] as String? ?? '';
    final isSpecific =
        validationGranularity == 'PREMISE' ||
        validationGranularity == 'SUB_PREMISE';
    return isSpecific &&
        verdict['addressComplete'] == true &&
        verdict['hasUnconfirmedComponents'] != true &&
        verdict['hasReplacedComponents'] != true &&
        verdict['hasInferredComponents'] != true;
  }

  SuggestedSiteAddress? _suggestionFromAddressValidationResult(
    Site site,
    Map<String, dynamic> result,
  ) {
    final address = result['address'] as Map<String, dynamic>?;
    final postal = address?['postalAddress'] as Map<String, dynamic>?;
    if (postal == null) {
      return null;
    }
    final rawLines = postal['addressLines'] as List<dynamic>? ?? [];
    final lines = rawLines
        .whereType<String>()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final location =
        (result['geocode'] as Map<String, dynamic>?)?['location']
            as Map<String, dynamic>?;
    final suggested = site.copyWith(
      addressLine1: lines.isEmpty ? site.addressLine1 : lines.first,
      addressLine2: lines.length < 2 ? '' : lines.skip(1).join(', '),
      suburb: _postalString(postal, 'locality', fallback: site.suburb),
      state: _postalString(postal, 'administrativeArea', fallback: site.state),
      postcode: _postalString(postal, 'postalCode', fallback: site.postcode),
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      geocodeStatus: 'ok',
      geocodedAt: DateTime.now(),
    );
    if (!_hasSpecificSiteAddress(suggested)) {
      return null;
    }
    return SuggestedSiteAddress(
      site: suggested,
      formattedAddress: suggested.address,
    );
  }

  String _postalString(
    Map<String, dynamic> postal,
    String key, {
    required String fallback,
  }) {
    final value = postal[key] as String?;
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }

  String _addressValidationFailureMessage(http.Response response) {
    final decoded = _decodeGoogleResponse(response);
    final error = decoded?['error'] as Map<String, dynamic>?;
    final status = error?['status'] as String?;
    final message = (error?['message'] as String?)?.trim();
    if (_isAddressValidationRateLimit(response)) {
      return 'Google address validation quota has been reached. Try again '
          'later or check the Address Validation API quota for this Google '
          'Maps API key.';
    }
    if (response.statusCode == 403 || status == 'PERMISSION_DENIED') {
      return 'Google address validation failed: enable Address Validation API '
          'for this Google Maps API key.';
    }
    if (message != null && message.isNotEmpty) {
      return 'Google address validation failed: $message';
    }
    return 'Google address validation failed with HTTP '
        '${response.statusCode}.';
  }

  bool _isAddressValidationRateLimit(http.Response response) {
    final decoded = _decodeGoogleResponse(response);
    final error = decoded?['error'] as Map<String, dynamic>?;
    return _isGoogleRateLimit(response, decoded: decoded, error: error);
  }

  String _placesFailureMessage(http.Response response) {
    final decoded = _decodeGoogleResponse(response);
    final error = decoded?['error'] as Map<String, dynamic>?;
    final status = error?['status'] as String?;
    final message = (error?['message'] as String?)?.trim();
    if (_isGoogleRateLimit(response, decoded: decoded, error: error)) {
      return 'Google Places suggestion quota has been reached. Try again '
          'later or check the Places API quota for this Google Maps API key.';
    }
    if (response.statusCode == 403 || status == 'PERMISSION_DENIED') {
      return 'Google Places suggestions failed: enable Places API (New) for '
          'this Google Maps API key.';
    }
    if (message != null && message.isNotEmpty) {
      return 'Google Places suggestions failed: $message';
    }
    return 'Google Places suggestions failed with HTTP ${response.statusCode}.';
  }

  bool _isGoogleRateLimit(
    http.Response response, {
    Map<String, dynamic>? decoded,
    Map<String, dynamic>? error,
  }) {
    final body = decoded ?? _decodeGoogleResponse(response);
    final googleError = error ?? (body?['error'] as Map<String, dynamic>?);
    return response.statusCode == 429 ||
        googleError?['status'] == 'RESOURCE_EXHAUSTED';
  }

  bool _addressNeedsAttention(Site current, Site suggested) {
    if (_normaliseAddressPart(current.addressLine1) !=
        _normaliseAddressPart(suggested.addressLine1)) {
      return true;
    }
    if (_normaliseAddressPart(current.suburb) !=
        _normaliseAddressPart(suggested.suburb)) {
      return true;
    }
    if (current.state.trim().isNotEmpty &&
        _normaliseAddressPart(current.state) !=
            _normaliseAddressPart(suggested.state)) {
      return true;
    }
    if (current.postcode.trim().isNotEmpty &&
        _normaliseAddressPart(current.postcode) !=
            _normaliseAddressPart(suggested.postcode)) {
      return true;
    }
    return false;
  }

  String _normaliseAddressPart(String value) {
    final replacements = {
      'road': 'rd',
      'street': 'st',
      'avenue': 'ave',
      'drive': 'drv',
      'crescent': 'cres',
      'court': 'ct',
      'place': 'pl',
      'parade': 'pde',
      'highway': 'hwy',
      'lane': 'ln',
    };
    final parts = value
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => replacements[part] ?? part);
    return parts.join(' ');
  }

  Future<void> launchDirections({
    required List<MailingRecipient> recipients,
    String? origin,
  }) async {
    final selected = recipients
        .where((recipient) => recipient.hasAddress && !recipient.excluded)
        .toList();
    if (selected.isEmpty) {
      return;
    }
    final destination = selected.last.address;
    final waypoints = selected.take(selected.length - 1).map((e) => e.address);
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      if (origin?.trim().isNotEmpty ?? false) 'origin': origin!.trim(),
      'destination': destination,
      if (waypoints.isNotEmpty) 'waypoints': waypoints.join('|'),
      'travelmode': 'driving',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<MailingRecipient> _fallbackOrder(List<MailingRecipient> recipients) =>
      [...recipients]..sort((a, b) {
        final suburb = a.suburb.compareTo(b.suburb);
        if (suburb != 0) {
          return suburb;
        }
        final postcode = a.postcode.compareTo(b.postcode);
        if (postcode != 0) {
          return postcode;
        }
        return a.addressLine1.compareTo(b.addressLine1);
      });

  RouteOptimisationResult _failedResult(
    List<MailingRecipient> recipients,
    String reason, {
    MailingRecipient? failedRecipient,
  }) => RouteOptimisationResult(
    recipients: _fallbackOrder(recipients),
    fallbackReason: reason,
    failedRecipient: failedRecipient,
  );

  String _googleErrorMessage(http.Response response, String fallback) {
    final decoded = _decodeGoogleResponse(response);
    final error = decoded?['error'] as Map<String, dynamic>?;
    final message = error?['message'] as String?;
    if (message != null && message.trim().isNotEmpty) {
      return message;
    }
    return fallback;
  }

  Map<String, dynamic>? _decodeGoogleResponse(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _debugRouteResponse({
    required String reason,
    required List<MailingRecipient> routeable,
    required String responseBody,
    int? statusCode,
  }) {
    if (!kDebugMode) {
      return;
    }
    final status = statusCode == null ? '' : 'statusCode=$statusCode; ';
    debugPrint(
      '[MailingRouteDiagnostic] $reason; '
      '$status'
      'intermediateCount=${routeable.length}',
    );
    const maxLineLength = 800;
    for (var start = 0; start < responseBody.length; start += maxLineLength) {
      final end = (start + maxLineLength).clamp(0, responseBody.length);
      final chunk = responseBody.substring(start, end);
      final chunkIndex = start ~/ maxLineLength;
      debugPrint('[MailingRouteDiagnostic] response[$chunkIndex]=$chunk');
    }
    if (responseBody.isEmpty) {
      debugPrint('[MailingRouteDiagnostic] response=');
    }
  }
}
