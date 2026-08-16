import 'dart:convert';

import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/tools/mailings/google_maps_route_service.dart';
import 'package:hmb/ui/tools/mailings/label_layout.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('suggestSiteAddress parses an Address Validation suggestion', () async {
    late final http.Request capturedRequest;
    final service = GoogleMapsRouteService(
      apiKeyProvider: () async => 'test-key',
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode(_addressValidationSuccess), 200);
      }),
    );

    final suggestion = await service.suggestSiteAddress(
      Site.forInsert(
        addressLine1: '126 Beverley Rd',
        addressLine2: '',
        suburb: 'rossanna',
        state: '',
        postcode: '',
        accessDetails: '',
      ),
    );

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.host, 'addressvalidation.googleapis.com');
    expect(capturedRequest.url.path, '/v1:validateAddress');
    expect(capturedRequest.url.queryParameters['key'], 'test-key');
    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(body['address'], {
      'regionCode': 'AU',
      'addressLines': ['126 Beverley Rd'],
      'locality': 'rossanna',
    });
    expect(suggestion, isNotNull);
    expect(
      suggestion!.formattedAddress,
      '126 Beverley Road, Rosanna, VIC, 3084',
    );
    expect(suggestion.site.addressLine1, '126 Beverley Road');
    expect(suggestion.site.suburb, 'Rosanna');
    expect(suggestion.site.state, 'VIC');
    expect(suggestion.site.postcode, '3084');
    expect(suggestion.site.latitude, -37.742);
    expect(suggestion.site.longitude, 145.067);
  });

  test('validateRecipients does not geocode the business address', () async {
    final recipient = await _insertMailingRecipient(suburb: 'Rosanna');
    final requests = <http.Request>[];
    final service = GoogleMapsRouteService(
      apiKeyProvider: () async => 'test-key',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(_addressValidationSuccess), 200);
      }),
    );

    final issues = await service.validateRecipients(
      recipients: [recipient],
      businessAddress: '1 Business Rd, Ivanhoe VIC 3079',
    );

    expect(issues, isEmpty);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.host, 'addressvalidation.googleapis.com');
  });

  test('validateRecipients reports Address Validation failures', () async {
    final recipient = await _insertMailingRecipient();
    final service = GoogleMapsRouteService(
      apiKeyProvider: () async => 'test-key',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        return http.Response(
          jsonEncode({
            'error': {
              'code': 403,
              'message': 'Address Validation API has not been enabled.',
              'status': 'PERMISSION_DENIED',
            },
          }),
          403,
        );
      }),
    );

    final issues = await service.validateRecipients(recipients: [recipient]);

    expect(issues, hasLength(1));
    expect(issues.single.recipient?.id, recipient.id);
    expect(issues.single.suggestion, isNull);
    expect(
      issues.single.suggestionFailure,
      'Google address validation failed: enable Address Validation API for '
      'this Google Maps API key.',
    );
  });

  test(
    'validateRecipients stops batch on Address Validation quota limit',
    () async {
      final first = await _insertMailingRecipient(
        customerName: 'Quota Customer One',
      );
      final second = await _insertMailingRecipient(
        customerName: 'Quota Customer Two',
      );
      var requestCount = 0;
      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          requestCount++;
          return http.Response(
            jsonEncode({
              'error': {
                'code': 429,
                'message': 'Quota exceeded.',
                'status': 'RESOURCE_EXHAUSTED',
              },
            }),
            429,
          );
        }),
      );

      final issues = await service.validateRecipients(
        recipients: [first, second],
      );

      expect(requestCount, 1);
      expect(issues, hasLength(1));
      expect(issues.single.recipient, isNull);
      expect(issues.single.message, 'Address validation stopped.');
      expect(
        issues.single.suggestionFailure,
        contains('quota has been reached'),
      );
    },
  );

  test(
    'validateRecipients reports unaccepted normalized suggestions',
    () async {
      final recipient = await _insertMailingRecipient(suburb: 'Mernda');
      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          return http.Response(jsonEncode(_addressValidationReview), 200);
        }),
      );

      final issues = await service.validateRecipients(recipients: [recipient]);

      expect(issues, hasLength(1));
      expect(issues.single.suggestions, hasLength(1));
      expect(
        issues.single.suggestion!.formattedAddress,
        '22 James Street, Mernda, VIC, 3754',
      );
      expect(
        (await DaoSite().getById(recipient.siteId))!.geocodeStatus,
        'invalid',
      );
    },
  );

  test(
    'validateRecipients suggests address when site name holds street',
    () async {
      final recipient = await _insertMailingRecipient(
        siteName: '4/3 kenilworth parade',
        addressLine1: '',
        suburb: 'Ivanhoe',
      );
      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect((body['address'] as Map<String, dynamic>)['addressLines'], [
            '4/3 kenilworth parade',
          ]);
          return http.Response(jsonEncode(_addressValidationKenilworth), 200);
        }),
      );

      final issues = await service.validateRecipients(recipients: [recipient]);

      expect(issues, hasLength(1));
      expect(issues.single.recipient?.id, recipient.id);
      expect(
        issues.single.suggestion?.site.addressLine1,
        '4/3 Kenilworth Parade',
      );
      expect(issues.single.suggestion?.site.suburb, 'Ivanhoe');
    },
  );

  test(
    'validateRecipients uses Address Validation and caches clean addresses',
    () async {
      final recipient = await _insertMailingRecipient(suburb: 'Rosanna');
      var requestCount = 0;
      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          requestCount++;
          return http.Response(jsonEncode(_addressValidationSuccess), 200);
        }),
      );

      final issues = await service.validateRecipients(recipients: [recipient]);
      final site = await DaoSite().getById(recipient.siteId);

      expect(issues, isEmpty);
      expect(requestCount, 1);
      expect(site!.geocodeStatus, 'ok');
      expect(site.latitude, -37.742);
      expect(site.longitude, 145.067);

      final cachedService = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((_) {
          fail('Validated addresses must not be validated again.');
        }),
      );

      expect(
        await cachedService.validateRecipients(recipients: [recipient]),
        isEmpty,
      );
    },
  );

  test(
    'validateRecipients does not trust cached geocode for vague address',
    () async {
      final recipient = await _insertMailingRecipient(
        addressLine1: 'Upper Heidelberg Rd',
        suburb: 'Ivanhoe',
      );
      await _markSiteValid(recipient.siteId);
      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((_) {
          fail('Vague addresses must not spend a validation request.');
        }),
      );

      final issues = await service.validateRecipients(recipients: [recipient]);
      final site = await DaoSite().getById(recipient.siteId);

      expect(issues, hasLength(1));
      expect(issues.single.recipient?.id, recipient.id);
      expect(
        issues.single.suggestionFailure,
        'Address must include a street number and suburb.',
      );
      expect(site!.geocodeStatus, 'invalid');
      expect(site.latitude, isNull);
      expect(site.longitude, isNull);
    },
  );

  test(
    'validateRecipients ignores persisted route failures by default',
    () async {
      final recipient = await _insertMailingRecipient();
      final site = await DaoSite().getById(recipient.siteId);
      await DaoSite().update(
        site!.copyWith(
          latitude: -37.742,
          longitude: 145.067,
          geocodeStatus: 'route_failed',
          geocodedAt: DateTime(2026),
        ),
      );
      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((_) {
          fail('Validated route failure must not be geocoded again.');
        }),
      );

      final issues = await service.validateRecipients(recipients: [recipient]);

      expect(issues, isEmpty);
    },
  );

  test('route readiness reports persisted route failures', () async {
    final recipient = await _insertMailingRecipient();
    final site = await DaoSite().getById(recipient.siteId);
    await DaoSite().update(
      site!.copyWith(
        latitude: -37.742,
        longitude: 145.067,
        geocodeStatus: 'route_failed',
        geocodedAt: DateTime(2026),
      ),
    );
    var validationCount = 0;
    var placesCount = 0;
    var routeCount = 0;
    final service = GoogleMapsRouteService(
      apiKeyProvider: () async => 'test-key',
      client: MockClient((request) async {
        if (request.url.host == 'routes.googleapis.com') {
          routeCount++;
          fail('Persisted route failures must not be route-checked again.');
        }
        if (request.url.host == 'places.googleapis.com') {
          placesCount++;
          return http.Response(jsonEncode(_placesAutocompleteKenilworth), 200);
        }
        validationCount++;
        return http.Response(jsonEncode(_addressValidationSuccess), 200);
      }),
    );

    final issues = await service.validateRecipients(
      recipients: [recipient],
      checkRouteReadiness: true,
    );

    expect(issues, hasLength(1));
    expect(issues.single.recipient?.id, recipient.id);
    expect(issues.single.message, contains('Route planning needs attention'));
    expect(issues.single.suggestions, isNotEmpty);
    expect(issues.single.suggestionFailure, isNull);
    expect(validationCount, 2);
    expect(placesCount, 1);
    expect(routeCount, 0);
    expect(
      (await DaoSite().getById(recipient.siteId))!.geocodeStatus,
      'route_failed',
    );
  });

  test(
    'validateRecipients uses Places when validation cannot suggest a fix',
    () async {
      final recipient = await _insertMailingRecipient(
        customerName: 'Vito Ceniti',
        addressLine1: '36 Cedric Street',
        suburb: 'Ivanhoe',
      );
      var validationCount = 0;
      var placesCount = 0;
      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((request) async {
          if (request.url.host == 'places.googleapis.com') {
            placesCount++;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['input'], '36 Cedric Street, Ivanhoe');
            return http.Response(jsonEncode(_placesAutocompleteCedric), 200);
          }
          validationCount++;
          if (validationCount == 1) {
            return http.Response(
              jsonEncode(_addressValidationCedricUnchanged),
              200,
            );
          }
          return http.Response(
            jsonEncode(_addressValidationCedricEastIvanhoe),
            200,
          );
        }),
      );

      final issues = await service.validateRecipients(recipients: [recipient]);

      expect(issues, hasLength(1));
      expect(issues.single.recipient?.id, recipient.id);
      expect(issues.single.suggestions, hasLength(1));
      expect(
        issues.single.suggestion!.site.address,
        '36 Cedric Street, Ivanhoe East, VIC, 3079',
      );
      expect(validationCount, 2);
      expect(placesCount, 1);
    },
  );

  test(
    'validateRecipients route-checks edited addresses before marking ok',
    () async {
      final recipient = await _insertMailingRecipient(
        customerName: 'Patrick Small',
        addressLine1: '2/52 Lockley rd.',
        suburb: 'Ivanhoe',
      );
      final site = await DaoSite().getById(recipient.siteId);
      await DaoSite().update(
        site!.copyWith(clearGeocode: true, geocodeStatus: 'invalidated'),
      );
      var validationCount = 0;
      var routeCount = 0;
      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((request) async {
          if (request.url.host == 'addressvalidation.googleapis.com') {
            validationCount++;
            return http.Response(jsonEncode(_addressValidationLockley), 200);
          }
          routeCount++;
          final routeRequest = jsonDecode(request.body) as Map<String, dynamic>;
          final origin = routeRequest['origin'] as Map<String, dynamic>;
          expect(routeRequest['destination'], {'address': origin['address']});
          expect(routeRequest['intermediates'], [
            {'address': '2/52 Lockley Road, Ivanhoe, VIC, 3079'},
          ]);
          return http.Response(jsonEncode({'routes': <Object>[]}), 200);
        }),
      );

      final issues = await service.validateRecipients(
        recipients: [recipient],
        businessAddress: '10 Mossman Drv, Eaglemont, Victoria, 3084',
        checkRouteReadiness: true,
      );
      final updated = await DaoSite().getById(recipient.siteId);

      expect(validationCount, 1);
      expect(routeCount, 1);
      expect(issues, hasLength(1));
      expect(issues.single.recipient?.id, recipient.id);
      expect(issues.single.message, contains('Route planning needs attention'));
      expect(updated!.geocodeStatus, 'route_failed');
      expect(updated.latitude, -37.7683771);
      expect(updated.longitude, 145.0429223);
    },
  );

  test(
    'validateRecipients trusts cached geocode to avoid route quota spikes',
    () async {
      final recipient = await _insertMailingRecipient(
        customerName: 'Patrick Small',
        addressLine1: '2/52 Lockley rd.',
        suburb: 'Ivanhoe',
      );
      await _markSiteValid(
        recipient.siteId,
        latitude: -37.7683771,
        longitude: 145.0429223,
      );
      var routeCount = 0;
      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((request) {
          routeCount++;
          fail(
            'Validated addresses must not be route-checked in bulk validation.',
          );
        }),
      );

      final issues = await service.validateRecipients(
        recipients: [recipient],
        businessAddress: '10 Mossman Drv, Eaglemont, Victoria, 3084',
        checkRouteReadiness: true,
      );
      final updated = await DaoSite().getById(recipient.siteId);

      expect(routeCount, 0);
      expect(issues, isEmpty);
      expect(updated!.geocodeStatus, 'ok');
    },
  );

  test('route failure marks isolated recipient address invalid', () async {
    final first = await _insertMailingRecipient(
      customerName: 'Route Customer One',
    );
    final second = await _insertMailingRecipient(
      customerName: 'Route Customer Two',
    );
    await _markSiteValid(first.siteId);
    await _markSiteValid(second.siteId);

    final service = GoogleMapsRouteService(
      apiKeyProvider: () async => 'test-key',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        return http.Response(jsonEncode({'routes': <Object>[]}), 200);
      }),
    );

    final result = await service.optimiseWithResult(
      origin: '1 Business St, Melbourne, VIC',
      recipients: [first, second],
    );
    final firstSite = await DaoSite().getById(first.siteId);
    final secondSite = await DaoSite().getById(second.siteId);

    expect(result.fallbackReason, isNotNull);
    expect(firstSite!.geocodeStatus, 'route_failed');
    expect(firstSite.latitude, isNull);
    expect(firstSite.longitude, isNull);
    expect(secondSite!.geocodeStatus, 'route_failed');
    expect(secondSite.latitude, isNull);
    expect(secondSite.longitude, isNull);
  });

  test('route split fallback starts right half from left result', () async {
    final first = await _insertMailingRecipient(
      customerName: 'Split Route Customer One',
    );
    final second = await _insertMailingRecipient(
      customerName: 'Split Route Customer Two',
    );
    await _markSiteValid(first.siteId);
    await _markSiteValid(second.siteId);

    var postCount = 0;
    final service = GoogleMapsRouteService(
      apiKeyProvider: () async => 'test-key',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        postCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final origin = body['origin'] as Map<String, dynamic>;
        final destination = body['destination'] as Map<String, dynamic>;

        switch (postCount) {
          case 1:
            expect(origin['address'], '1 Business St, Melbourne, VIC');
            expect(destination['address'], second.address);
            return http.Response(jsonEncode({'routes': <Object>[]}), 200);
          case 2:
            expect(origin['address'], '1 Business St, Melbourne, VIC');
            expect(destination['address'], first.address);
            return http.Response(
              jsonEncode({
                'routes': [<String, Object>{}],
              }),
              200,
            );
          case 3:
            expect(origin['address'], first.address);
            expect(destination['address'], second.address);
            return http.Response(
              jsonEncode({
                'routes': [<String, Object>{}],
              }),
              200,
            );
          default:
            fail('Unexpected route request $postCount.');
        }
      }),
    );

    final result = await service.optimiseWithResult(
      origin: '1 Business St, Melbourne, VIC',
      recipients: [first, second],
    );

    expect(postCount, 3);
    expect(result.fallbackReason, isNull);
    expect(result.recipients.map((recipient) => recipient.id), [
      first.id,
      second.id,
    ]);
  });

  test(
    'route split does not invalidate stop routeable from business origin',
    () async {
      final first = await _insertMailingRecipient(
        customerName: 'Boundary Route Customer One',
      );
      final second = await _insertMailingRecipient(
        customerName: 'Boundary Route Customer Two',
      );
      await _markSiteValid(first.siteId);
      await _markSiteValid(second.siteId);

      var postCount = 0;
      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          postCount++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final origin = body['origin'] as Map<String, dynamic>;
          final destination = body['destination'] as Map<String, dynamic>;

          switch (postCount) {
            case 1:
              expect(origin['address'], '1 Business St, Melbourne, VIC');
              expect(destination['address'], second.address);
              return http.Response(jsonEncode({'routes': <Object>[]}), 200);
            case 2:
              expect(origin['address'], '1 Business St, Melbourne, VIC');
              expect(destination['address'], first.address);
              return http.Response(
                jsonEncode({
                  'routes': [<String, Object>{}],
                }),
                200,
              );
            case 3:
              expect(origin['address'], first.address);
              expect(destination['address'], second.address);
              return http.Response(jsonEncode({'routes': <Object>[]}), 200);
            case 4:
              expect(origin['address'], first.address);
              expect(destination['address'], second.address);
              return http.Response(jsonEncode({'routes': <Object>[]}), 200);
            case 5:
              expect(origin['address'], '1 Business St, Melbourne, VIC');
              expect(destination['address'], second.address);
              return http.Response(
                jsonEncode({
                  'routes': [<String, Object>{}],
                }),
                200,
              );
            default:
              fail('Unexpected route request $postCount.');
          }
        }),
      );

      final result = await service.optimiseWithResult(
        origin: '1 Business St, Melbourne, VIC',
        recipients: [first, second],
      );
      final secondSite = await DaoSite().getById(second.siteId);

      expect(postCount, 5);
      expect(result.fallbackReason, isNull);
      expect(secondSite!.geocodeStatus, 'ok');
      expect(result.recipients.map((recipient) => recipient.id), [
        first.id,
        second.id,
      ]);
    },
  );

  test('route split quota failure does not invalidate recipient', () async {
    final first = await _insertMailingRecipient(
      customerName: 'Quota Boundary Customer One',
    );
    final second = await _insertMailingRecipient(
      customerName: 'Quota Boundary Customer Two',
    );
    await _markSiteValid(first.siteId);
    await _markSiteValid(second.siteId);

    var postCount = 0;
    final service = GoogleMapsRouteService(
      apiKeyProvider: () async => 'test-key',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        postCount++;
        switch (postCount) {
          case 1:
            return http.Response(jsonEncode({'routes': <Object>[]}), 200);
          case 2:
            return http.Response(
              jsonEncode({
                'routes': [<String, Object>{}],
              }),
              200,
            );
          default:
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 429,
                  'message': 'Quota exceeded.',
                  'status': 'RESOURCE_EXHAUSTED',
                },
              }),
              429,
            );
        }
      }),
    );

    final result = await service.optimiseWithResult(
      origin: '1 Business St, Melbourne, VIC',
      recipients: [first, second],
    );
    final secondSite = await DaoSite().getById(second.siteId);

    expect(result.fallbackReason, 'Quota exceeded.');
    expect(result.failedRecipient, isNull);
    expect(secondSite!.geocodeStatus, 'ok');
  });

  test('route optimisation stops chunking after quota failure', () async {
    final recipients = <MailingRecipient>[];
    for (var i = 0; i < 26; i++) {
      final recipient = await _insertMailingRecipient(
        customerName: 'Quota Route Customer $i',
      );
      await _markSiteValid(recipient.siteId);
      recipients.add(recipient);
    }
    var requestCount = 0;

    final service = GoogleMapsRouteService(
      apiKeyProvider: () async => 'test-key',
      client: MockClient((request) async {
        if (request.url.host == 'addressvalidation.googleapis.com') {
          return http.Response(jsonEncode(_addressValidationOrigin), 200);
        }
        requestCount++;
        return http.Response(
          jsonEncode({
            'error': {
              'code': 429,
              'message': 'Quota exceeded.',
              'status': 'RESOURCE_EXHAUSTED',
            },
          }),
          429,
        );
      }),
    );

    final result = await service.optimiseWithResult(
      origin: '1 Business St, Melbourne, VIC',
      recipients: recipients,
    );

    expect(requestCount, 1);
    expect(result.fallbackReason, 'Quota exceeded.');
  });

  test(
    'route optimisation chooses the shortest destination candidate',
    () async {
      final near = await _insertMailingRecipient(
        customerName: 'Near Stop',
        addressLine1: '1 Test Road',
        suburb: 'Routeville',
      );
      await _markSiteValid(near.siteId, latitude: 0, longitude: 1);
      final far = await _insertMailingRecipient(
        customerName: 'Far Stop',
        addressLine1: '5 Test Road',
        suburb: 'Routeville',
      );
      await _markSiteValid(far.siteId, latitude: 0, longitude: 5);
      final middle = await _insertMailingRecipient(
        customerName: 'Middle Stop',
        addressLine1: '3 Test Road',
        suburb: 'Routeville',
      );
      await _markSiteValid(middle.siteId, latitude: 0, longitude: 3);
      final destinations = <String>[];

      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((request) async {
          if (request.url.host == 'addressvalidation.googleapis.com') {
            return http.Response(jsonEncode(_addressValidationOrigin), 200);
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final destination =
              (body['destination'] as Map<String, dynamic>)['address']
                  as String;
          destinations.add(destination);
          final intermediates = body['intermediates'] as List<dynamic>? ?? [];
          return http.Response(
            jsonEncode({
              'routes': [
                {
                  'distanceMeters': destination.startsWith('5 Test Road')
                      ? 100
                      : destination.startsWith('3 Test Road')
                      ? 900
                      : 1100,
                  'optimizedIntermediateWaypointIndex': [
                    for (var i = 0; i < intermediates.length; i++) i,
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.optimiseWithResult(
        origin: '0 Origin Road, Routeville',
        recipients: [near, far, middle],
      );

      expect(result.fallbackReason, isNull);
      expect(destinations, hasLength(3));
      expect(destinations.first, startsWith('3 Test Road'));
      expect(
        destinations.any((address) => address.startsWith('5 Test Road')),
        isTrue,
      );
      expect(result.recipients.map((recipient) => recipient.customerName), [
        'Near Stop',
        'Middle Stop',
        'Far Stop',
      ]);
    },
  );

  test(
    'route optimisation preorders all chunks by nearest neighbour and two opt',
    () async {
      final recipients = <MailingRecipient>[];
      for (var distance = 30; distance >= 1; distance--) {
        final recipient = await _insertMailingRecipient(
          customerName: 'Stop $distance',
          addressLine1: '$distance Test Road',
          suburb: 'Routeville',
        );
        await _markSiteValid(
          recipient.siteId,
          latitude: 0,
          longitude: distance.toDouble(),
        );
        recipients.add(recipient);
      }
      final routeRequests = <Map<String, dynamic>>[];

      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((request) async {
          if (request.url.host == 'addressvalidation.googleapis.com') {
            return http.Response(jsonEncode(_addressValidationOrigin), 200);
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          routeRequests.add(body);
          final intermediates = body['intermediates'] as List<dynamic>? ?? [];
          return http.Response(
            jsonEncode({
              'routes': [
                if (intermediates.length > 1)
                  {
                    'optimizedIntermediateWaypointIndex': [
                      for (var i = 0; i < intermediates.length; i++) i,
                    ],
                  }
                else
                  <String, Object>{},
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.optimiseWithResult(
        origin: '0 Origin Road, Routeville',
        recipients: recipients,
      );

      expect(result.fallbackReason, isNull);
      expect(result.recipients.map((recipient) => recipient.customerName), [
        for (var distance = 1; distance <= 30; distance++) 'Stop $distance',
      ]);
      expect(routeRequests, hasLength(4));
      expect(
        (routeRequests.first['destination'] as Map<String, dynamic>)['address'],
        startsWith('25 Test Road'),
      );
      final firstIntermediateAddress =
          ((routeRequests.first['intermediates'] as List<dynamic>).first
                  as Map<String, dynamic>)['address']
              as String;
      expect(firstIntermediateAddress, startsWith('1 Test Road'));
      expect(
        (routeRequests[2]['origin'] as Map<String, dynamic>)['address'],
        startsWith('25 Test Road'),
      );
      expect(
        (routeRequests[2]['destination'] as Map<String, dynamic>)['address'],
        startsWith('30 Test Road'),
      );
    },
  );

  test(
    'split single stop route with minus one waypoint order succeeds',
    () async {
      final first = await _insertMailingRecipient(
        customerName: 'Route Customer One',
      );
      final second = await _insertMailingRecipient(
        customerName: 'Route Customer Two',
      );
      await _markSiteValid(first.siteId);
      await _markSiteValid(second.siteId);
      var requestCount = 0;

      final service = GoogleMapsRouteService(
        apiKeyProvider: () async => 'test-key',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          requestCount++;
          if (requestCount == 1) {
            return http.Response(jsonEncode({'routes': <Object>[]}), 200);
          }
          return http.Response(
            jsonEncode({
              'routes': [
                {
                  'optimizedIntermediateWaypointIndex': [-1],
                },
              ],
              'geocodingResults': {
                'origin': {'geocoderStatus': <String, Object>{}},
                'destination': {'geocoderStatus': <String, Object>{}},
                'intermediates': [
                  {
                    'geocoderStatus': <String, Object>{},
                    'intermediateWaypointRequestIndex': 0,
                  },
                ],
              },
            }),
            200,
          );
        }),
      );

      final result = await service.optimiseWithResult(
        origin: '1 Business St, Melbourne, VIC',
        recipients: [first, second],
      );
      final firstSite = await DaoSite().getById(first.siteId);
      final secondSite = await DaoSite().getById(second.siteId);

      expect(requestCount, 3);
      expect(result.recipients, [first, second]);
      expect(result.fallbackReason, isNull);
      expect(result.failedRecipient, isNull);
      expect(firstSite!.geocodeStatus, 'ok');
      expect(secondSite!.geocodeStatus, 'ok');
    },
  );
}

Future<MailingRecipient> _insertMailingRecipient({
  String customerName = 'Route Customer',
  String? siteName,
  String addressLine1 = '126 Beverley Rd',
  String suburb = 'rossanna',
}) async {
  final customer = Customer.forInsert(
    name: customerName,
    description: '',
    disbarred: false,
    customerType: CustomerType.residential,
    hourlyRate: MoneyEx.zero,
    billingContactId: null,
  );
  await DaoCustomer().insert(customer);

  final contact = Contact.forInsert(
    firstName: 'Margaret',
    surname: 'Tribiano',
    mobileNumber: '0400000000',
    landLine: '',
    officeNumber: '',
    emailAddress: 'margaret@example.com',
  );
  await DaoContact().insert(contact);
  await DaoContactCustomer().insertJoin(contact, customer);
  await DaoContactCustomer().setAsPrimary(contact, customer);

  final site = Site.forInsert(
    name: siteName,
    addressLine1: addressLine1,
    addressLine2: '',
    suburb: suburb,
    state: '',
    postcode: '',
    accessDetails: '',
  );
  await DaoSite().insert(site);
  await DaoSiteCustomer().insertJoin(site, customer);

  final mailing = Mailing.forInsert(
    name: 'Test mailing',
    labelLayoutId: LabelLayout.all.first.id,
  );
  await DaoMailing().insert(mailing);
  await DaoMailingRecipient().populateForMailing(mailing.id);

  return (await DaoMailingRecipient().getByMailing(
    mailing.id,
  )).singleWhere((recipient) => recipient.customerId == customer.id);
}

Future<void> _markSiteValid(
  int? siteId, {
  double latitude = -37.742,
  double longitude = 145.067,
}) async {
  final site = await DaoSite().getById(siteId);
  await DaoSite().update(
    site!.copyWith(
      latitude: latitude,
      longitude: longitude,
      geocodeStatus: 'ok',
      geocodedAt: DateTime(2026),
    ),
  );
}

const Map<String, Map<String, Map<String, Object>>> _addressValidationSuccess =
    {
      'result': {
        'verdict': {
          'validationGranularity': 'PREMISE',
          'addressComplete': true,
        },
        'address': {
          'postalAddress': {
            'regionCode': 'AU',
            'addressLines': ['126 Beverley Road'],
            'locality': 'Rosanna',
            'administrativeArea': 'VIC',
            'postalCode': '3084',
          },
        },
        'geocode': {
          'location': {'latitude': -37.742, 'longitude': 145.067},
        },
      },
    };

const Map<String, Map<String, Map<String, Object>>> _addressValidationReview = {
  'result': {
    'verdict': {
      'validationGranularity': 'PREMISE',
      'addressComplete': true,
      'hasReplacedComponents': true,
    },
    'address': {
      'postalAddress': {
        'regionCode': 'AU',
        'addressLines': ['22 James Street'],
        'locality': 'Mernda',
        'administrativeArea': 'VIC',
        'postalCode': '3754',
      },
    },
    'geocode': {
      'location': {'latitude': -37.591, 'longitude': 145.096},
    },
  },
};

const Map<String, Map<String, Map<String, Object>>>
_addressValidationKenilworth = {
  'result': {
    'verdict': {'validationGranularity': 'PREMISE', 'addressComplete': true},
    'address': {
      'postalAddress': {
        'regionCode': 'AU',
        'addressLines': ['4/3 Kenilworth Parade'],
        'locality': 'Ivanhoe',
        'administrativeArea': 'VIC',
        'postalCode': '3079',
      },
    },
    'geocode': {
      'location': {'latitude': -37.768, 'longitude': 145.044},
    },
  },
};

const Map<String, Map<String, Map<String, Object>>> _addressValidationLockley =
    {
      'result': {
        'verdict': {
          'validationGranularity': 'PREMISE',
          'addressComplete': true,
        },
        'address': {
          'postalAddress': {
            'regionCode': 'AU',
            'addressLines': ['2/52 Lockley Road'],
            'locality': 'Ivanhoe',
            'administrativeArea': 'VIC',
            'postalCode': '3079',
          },
        },
        'geocode': {
          'location': {'latitude': -37.7683771, 'longitude': 145.0429223},
        },
      },
    };

const Map<String, Map<String, Map<String, Object>>> _addressValidationOrigin = {
  'result': {
    'verdict': {'validationGranularity': 'PREMISE', 'addressComplete': true},
    'address': {
      'postalAddress': {
        'regionCode': 'AU',
        'addressLines': ['0 Origin Road'],
        'locality': 'Routeville',
      },
    },
    'geocode': {
      'location': {'latitude': 0, 'longitude': 0},
    },
  },
};

const Map<String, Map<String, Map<String, Object>>>
_addressValidationCedricUnchanged = {
  'result': {
    'verdict': {
      'validationGranularity': 'PREMISE',
      'addressComplete': true,
      'hasUnconfirmedComponents': true,
    },
    'address': {
      'postalAddress': {
        'regionCode': 'AU',
        'addressLines': ['36 Cedric Street'],
        'locality': 'Ivanhoe',
      },
    },
    'geocode': {
      'location': {'latitude': -37.769, 'longitude': 145.045},
    },
  },
};

const Map<String, Map<String, Map<String, Object>>>
_addressValidationCedricEastIvanhoe = {
  'result': {
    'verdict': {'validationGranularity': 'PREMISE', 'addressComplete': true},
    'address': {
      'postalAddress': {
        'regionCode': 'AU',
        'addressLines': ['36 Cedric Street'],
        'locality': 'Ivanhoe East',
        'administrativeArea': 'VIC',
        'postalCode': '3079',
      },
    },
    'geocode': {
      'location': {'latitude': -37.773, 'longitude': 145.064},
    },
  },
};

const Map<String, List<Map<String, Map<String, Object>>>>
_placesAutocompleteCedric = {
  'suggestions': [
    {
      'placePrediction': {
        'place': 'places/cedric-east-ivanhoe',
        'text': {'text': '36 Cedric Street, Ivanhoe East VIC 3079, Australia'},
      },
    },
  ],
};

const Map<String, List<Map<String, Map<String, Object>>>>
_placesAutocompleteKenilworth = {
  'suggestions': [
    {
      'placePrediction': {
        'place': 'places/kenilworth-ivanhoe',
        'text': {'text': '4/3 Kenilworth Parade, Ivanhoe VIC 3079, Australia'},
      },
    },
  ],
};
