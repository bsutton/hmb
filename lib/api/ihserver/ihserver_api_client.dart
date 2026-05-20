import 'dart:convert';

import 'package:booking_request/booking_request.dart' as br;
import 'package:http/http.dart' as http;

import '../../dao/dao_system.dart';

class IhServerApiClient {
  final http.Client _httpClient;
  final Future<IhServerApiConfig> Function() _configProvider;

  IhServerApiClient({
    http.Client? httpClient,
    Future<IhServerApiConfig> Function()? configProvider,
  }) : _httpClient = httpClient ?? http.Client(),
       _configProvider = configProvider ?? _loadConfig;

  static Future<IhServerApiConfig> _loadConfig() async {
    final system = await DaoSystem().get();
    return IhServerApiConfig(
      enabled: system.enableIhserverIntegration,
      baseUrl: system.ihserverUrl,
      token: system.ihserverToken,
    );
  }

  Future<List<br.BookingRequest>> fetchBookingRequests() async {
    final cfg = await _configProvider();
    if (!cfg.isValid) {
      return <br.BookingRequest>[];
    }

    final uri = Uri.parse('${cfg.normalizedBaseUrl}/api/hmb/booking/requests');
    final response = await _httpClient.get(uri, headers: cfg.authHeaders);
    if (response.statusCode != 200) {
      throw Exception(
        'ihserver error ${response.statusCode}: ${response.body}',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final list = payload['requests'] as List<dynamic>? ?? const [];
    return list
        .map(
          (e) =>
              br.BookingRequest.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> ackBookingRequests(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final cfg = await _configProvider();
    if (!cfg.isValid) {
      return;
    }

    final uri = Uri.parse('${cfg.normalizedBaseUrl}/api/hmb/booking/ack');
    final response = await _httpClient.post(
      uri,
      headers: {...cfg.authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({'ids': ids}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'ihserver ack error ${response.statusCode}: ${response.body}',
      );
    }
  }

  Future<void> rejectBookingRequest({
    required String id,
    required String reason,
    required BookingRequestRejectDelivery delivery,
    required String destination,
  }) async {
    final cfg = await _configProvider();
    if (!cfg.isValid) {
      throw Exception('ihserver is not configured');
    }

    final uri = Uri.parse('${cfg.normalizedBaseUrl}/api/hmb/booking/reject');
    final response = await _httpClient.post(
      uri,
      headers: {...cfg.authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': id,
        'reason': reason,
        'delivery_method': delivery.name,
        'destination': destination,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'ihserver reject error ${response.statusCode}: ${response.body}',
      );
    }
  }
}

enum BookingRequestRejectDelivery { email, sms }

class IhServerApiConfig {
  final bool enabled;
  final String? baseUrl;
  final String? token;

  IhServerApiConfig({
    required this.enabled,
    required this.baseUrl,
    required this.token,
  });

  bool get isValid =>
      enabled &&
      baseUrl != null &&
      baseUrl!.trim().isNotEmpty &&
      token != null &&
      token!.trim().isNotEmpty;

  String get normalizedBaseUrl =>
      baseUrl!.trim().replaceAll(RegExp(r'/*$'), '');

  Map<String, String> get authHeaders => {
    'Authorization': 'Bearer ${token!.trim()}',
  };
}
