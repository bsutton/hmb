import 'dart:convert';

import 'package:hmb/api/ihserver/ihserver_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('rejectBookingRequest sends delivery method and destination', () async {
    late final http.Request captured;
    final client = IhServerApiClient(
      configProvider: () async => IhServerApiConfig(
        enabled: true,
        baseUrl: 'https://ihserver.example',
        token: 'test-token',
      ),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      }),
    );

    await client.rejectBookingRequest(
      id: 'booking-123',
      reason: 'No availability this week.',
      delivery: BookingRequestRejectDelivery.sms,
      destination: '0400000000',
    );

    expect(captured.method, 'POST');
    expect(
      captured.url.toString(),
      'https://ihserver.example/api/hmb/booking/reject',
    );
    expect(captured.headers['Authorization'], 'Bearer test-token');
    expect(captured.headers['Content-Type'], 'application/json');
    expect(jsonDecode(captured.body), {
      'id': 'booking-123',
      'reason': 'No availability this week.',
      'delivery_method': 'sms',
      'destination': '0400000000',
    });
  });
}
