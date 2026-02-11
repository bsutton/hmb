import 'dart:convert';

import 'package:booking_request/booking_request.dart' as br;

import '../../dao/dao_booking_request.dart';
import '../../dao/dao_system.dart';
import '../../database/management/database_helper.dart';
import '../../entity/booking_request.dart';
import '../../util/dart/log.dart';
import 'ihserver_api_client.dart';

class BookingRequestSyncService {
  final IhServerApiClient _client;
  static DateTime? _lastAttempt;
  static var _inFlight = false;
  static const _minInterval = Duration(hours: 1);

  BookingRequestSyncService({IhServerApiClient? client})
    : _client = client ?? IhServerApiClient();

  Future<int> sync({bool force = false}) async {
    if (!DatabaseHelper().isOpen()) {
      return 0;
    }
    if (_inFlight) {
      return 0;
    }
    final now = DateTime.now();
    if (!force &&
        _lastAttempt != null &&
        now.difference(_lastAttempt!) < _minInterval) {
      return 0;
    }
    _lastAttempt = now;
    _inFlight = true;
    try {
      final system = await DaoSystem().get();
      if (!system.enableIhserverIntegration) {
        return 0;
      }

      final requests = await _client.fetchBookingRequests();
      if (requests.isEmpty) {
        return 0;
      }

      final dao = DaoBookingRequest();
      var added = 0;
      final ids = <String>[];
      for (final req in requests) {
        final id = req.id;
        ids.add(id);
        final existing = await dao.getByRemoteId(id);
        if (existing != null) {
          continue;
        }

        final payload = req.toJsonString();
        final entity = BookingRequest.forInsert(
          remoteId: id,
          status: BookingRequestStatus.pending,
          payload: payload,
        );
        await dao.insert(entity);
        added += 1;
      }

      try {
        await _client.ackBookingRequests(ids);
      } catch (e) {
        Log.e('Failed to ack booking requests: $e');
      }

      return added;
    } finally {
      _inFlight = false;
    }
  }
}

extension on br.BookingRequest {
  String toJsonString() => jsonEncode(toJson());
}
