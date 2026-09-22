import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/api/trip_capture_service.dart';
import 'package:hmb/entity/trip_log.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'requests road distance and duration without logging credentials',
    () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'routes.googleapis.com');
        expect(
          request.headers['X-Goog-FieldMask'],
          'routes.distanceMeters,routes.duration',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['travelMode'], 'DRIVE');
        expect(body['origin'], {
          'location': {
            'latLng': {'latitude': -37.0, 'longitude': 145.0},
          },
        });
        return http.Response(
          '{"routes":[{"distanceMeters":2400,"duration":"320s"}]}',
          200,
        );
      });
      addTearDown(client.close);
      expect(
        await TripRouteClient(client).distance(
          const TripPoint(-37, 145),
          const TripPoint(-37.01, 145),
          'test-only-key',
        ),
        (2400, 320),
      );
    },
  );
  test('route failure never substitutes a straight-line distance', () async {
    final client = MockClient((_) async => http.Response('{"routes":[]}', 200));
    addTearDown(client.close);
    await expectLater(
      TripRouteClient(client).distance(
        const TripPoint(-37, 145),
        const TripPoint(-37.01, 145),
        'test-only-key',
      ),
      throwsStateError,
    );
  });
}
