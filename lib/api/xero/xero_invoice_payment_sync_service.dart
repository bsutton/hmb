import 'dart:convert';

import '../../api/external_accounting.dart';
import '../../dao/dao.g.dart';
import '../../database/management/database_helper.dart';
import '../../entity/invoice.dart';
import '../../util/dart/log.dart';
import 'xero_api.dart';

class XeroInvoicePaymentSyncService {
  static DateTime? _lastAttempt;
  static var _inFlight = false;
  static const _minInterval = Duration(hours: 6);

  final XeroApi _xeroApi;
  final DaoInvoice _daoInvoice;

  XeroInvoicePaymentSyncService({XeroApi? xeroApi, DaoInvoice? daoInvoice})
    : _xeroApi = xeroApi ?? XeroApi(),
      _daoInvoice = daoInvoice ?? DaoInvoice();

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
      if (!(await ExternalAccounting().isEnabled())) {
        return 0;
      }

      await _xeroApi.login();
      final pending = await _daoInvoice.getUploadedUnpaid();
      var updated = 0;
      for (final invoice in pending) {
        try {
          final paidDate = await _loadPaidDate(invoice);
          if (paidDate != null) {
            await _daoInvoice.markPaid(invoice.id, paidDate: paidDate);
            updated += 1;
          }
        } catch (e, st) {
          Log.e('Failed to sync payment for invoice ${invoice.id}: $e\n$st');
        }
      }
      return updated;
    } catch (e, st) {
      Log.e('Failed to sync Xero invoice payments: $e\n$st');
      return 0;
    } finally {
      _inFlight = false;
    }
  }

  Future<DateTime?> _loadPaidDate(Invoice invoice) async {
    final externalId = invoice.externalInvoiceId;
    if (externalId == null || externalId.isEmpty) {
      return null;
    }

    final response = await _xeroApi.getInvoice(externalId);
    if (response.statusCode != 200) {
      return null;
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      return null;
    }
    final invoices = body['Invoices'];
    if (invoices is! List || invoices.isEmpty) {
      return null;
    }
    final remote = invoices.first;
    if (remote is! Map<String, dynamic>) {
      return null;
    }

    final status = (remote['Status'] as String?)?.toUpperCase() ?? '';
    final amountDue = _toDouble(remote['AmountDue']);
    final amountPaid = _toDouble(remote['AmountPaid']);
    final isPaid = status == 'PAID' || (amountDue <= 0 && amountPaid > 0);
    if (!isPaid) {
      return null;
    }

    return _parseXeroDate(remote['FullyPaidOnDate']) ?? DateTime.now();
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  DateTime? _parseXeroDate(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    final match = RegExp(r'/Date\((\d+)').firstMatch(value);
    if (match != null) {
      final millis = int.tryParse(match.group(1) ?? '');
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      }
    }
    return DateTime.tryParse(value);
  }
}
