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

        final fullName = '${req.firstName} ${req.surname}'.trim();
        final derivedName = fullName.isNotEmpty
            ? fullName
            : req.businessName.trim();
        final entity = BookingRequest.forInsert(
          remoteId: id,
          status: BookingRequestStatus.pending,
          name: derivedName,
          businessName: req.businessName.trim(),
          firstName: req.firstName.trim(),
          surname: req.surname.trim(),
          email: req.email.trim(),
          phone: req.phone.trim(),
          description: req.description.trim(),
          street: req.street.trim(),
          suburb: req.suburb.trim(),
          day1: req.day1.trim(),
          day2: req.day2.trim(),
          day3: req.day3.trim(),
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
