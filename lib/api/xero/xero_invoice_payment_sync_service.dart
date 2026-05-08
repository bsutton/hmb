import 'dart:convert';

import 'package:money2/money2.dart';

import '../../api/external_accounting.dart';
import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/exceptions.dart';
import '../../util/dart/log.dart';
import '../../util/dart/money_ex.dart';
import 'xero_invoice_payment_client.dart';

typedef XeroInvoicePaymentSyncErrorHandler =
    void Function(Object error, StackTrace stackTrace);

class XeroInvoicePaymentSyncService {
  static DateTime? _lastAttempt;
  static var _inFlight = false;
  static const _minInterval = Duration(hours: 6);

  late XeroInvoicePaymentClient _xeroClient;
  final DaoInvoice _daoInvoice;
  final DebtorLedgerService _ledgerService;

  XeroInvoicePaymentSyncService({
    XeroInvoicePaymentClient? xeroClient,
    DaoInvoice? daoInvoice,
    DebtorLedgerService? ledgerService,
    XeroLogin? login,
    XeroGetInvoice? getInvoice,
    XeroCreatePayment? createPayment,
    XeroCreateCreditNote? createCreditNote,
    XeroAllocateCreditNote? allocateCreditNote,
  }) : _daoInvoice = daoInvoice ?? DaoInvoice(),
       _ledgerService = ledgerService ?? DebtorLedgerService() {
    _xeroClient = xeroClient ?? createDefaultXeroInvoicePaymentClient();
    if (login != null ||
        getInvoice != null ||
        createPayment != null ||
        createCreditNote != null ||
        allocateCreditNote != null) {
      _xeroClient = XeroInvoicePaymentClient(
        login: login ?? _xeroClient.login,
        getInvoice: getInvoice ?? _xeroClient.getInvoice,
        createPayment: createPayment ?? _xeroClient.createPayment,
        createCreditNote: createCreditNote ?? _xeroClient.createCreditNote,
        allocateCreditNote:
            allocateCreditNote ?? _xeroClient.allocateCreditNote,
      );
    }
  }

  Future<int> sync({
    bool force = false,
    XeroInvoicePaymentSyncErrorHandler? onError,
  }) async {
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

      final pending = await _daoInvoice.getUploadedUnpaid();
      final unsyncedPayments = await DaoDebtorPayment().getUnsyncedForProvider(
        'xero',
      );
      final unsyncedCredits = await DaoCreditNote().getUnsyncedForProvider(
        'xero',
      );
      if (pending.isEmpty) {
        Log.i('No unpaid Xero invoices need import syncing.');
      }
      if (pending.isEmpty &&
          unsyncedPayments.isEmpty &&
          unsyncedCredits.isEmpty) {
        Log.i('Skipping Xero payment sync because nothing needs syncing.');
        return 0;
      }

      final loggedIn = await _xeroClient.login(allowInteractive: false);
      if (!loggedIn) {
        Log.i(
          'Skipping Xero payment sync because silent login was unavailable.',
        );
        return 0;
      }
      var updated = 0;
      for (final invoice in pending) {
        try {
          final remoteState = await _loadRemoteState(invoice);
          if (remoteState == null) {
            continue;
          }
          if (invoice.externalSyncStatus != remoteState.externalSyncStatus) {
            await _daoInvoice.updateExternalSyncStatus(
              invoice.id,
              remoteState.externalSyncStatus,
            );
          }
          if (remoteState.paidDate != null) {
            await _daoInvoice.markPaidFromXero(
              invoice.id,
              paidDate: remoteState.paidDate,
            );
          }
          updated += await _importPayments(invoice, remoteState.payments);
          updated += await _importCreditNotes(invoice, remoteState.creditNotes);
          if (remoteState.paidDate != null &&
              remoteState.payments.isEmpty &&
              remoteState.creditNotes.isEmpty) {
            updated += 1;
          }
        } catch (e, st) {
          Log.e('Failed to sync payment for invoice ${invoice.id}: $e\n$st');
        }
      }
      updated += await _pushLocalPayments();
      updated += await _pushLocalCreditNotes();
      return updated;
    } catch (e, st) {
      if (_isConfigurationWarning(e)) {
        Log.w('Skipping Xero invoice payment sync: $e');
      } else {
        Log.e('Failed to sync Xero invoice payments: $e\n$st');
      }
      onError?.call(e, st);
      return 0;
    } finally {
      _inFlight = false;
    }
  }

  Future<int> _pushLocalPayments() async {
    final payments = await DaoDebtorPayment().getUnsyncedForProvider('xero');
    var pushed = 0;
    for (final payment in payments) {
      final allocations = await DaoPaymentAllocation().getByPaymentId(
        payment.id,
      );
      for (final allocation in allocations) {
        if (allocation.externalAllocationId != null) {
          continue;
        }
        final invoice = await _daoInvoice.getById(allocation.invoiceId);
        if (invoice?.externalInvoiceId == null) {
          continue;
        }
        final response = await _xeroClient.createPayment({
          'Invoice': {'InvoiceID': invoice!.externalInvoiceId},
          'Date': _xeroDate(allocation.allocatedDate),
          'Amount': _xeroAmount(allocation.amount),
          if (payment.reference != null) 'Reference': payment.reference,
          if (payment.paymentMethod != null)
            'Account': {'Code': payment.paymentMethod},
        });
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }
        final externalId = _firstExternalId(response.body, 'PaymentID');
        await DaoPaymentAllocation().update(
          allocation.copyWith(externalAllocationId: externalId ?? 'xero'),
        );
        if (externalId != null) {
          await DaoDebtorPayment().markExternal(
            payment: payment,
            provider: 'xero',
            externalPaymentId: externalId,
          );
        }
        pushed += 1;
      }
    }
    return pushed;
  }

  Future<int> _pushLocalCreditNotes() async {
    final creditNotes = await DaoCreditNote().getUnsyncedForProvider('xero');
    var pushed = 0;
    for (final creditNote in creditNotes) {
      final invoiceId = creditNote.relatedInvoiceId;
      final invoice = invoiceId == null
          ? null
          : await _daoInvoice.getById(invoiceId);
      if (invoice?.externalInvoiceId == null) {
        continue;
      }
      final response = await _xeroClient.createCreditNote({
        'Type': 'ACCRECCREDIT',
        'Date': _xeroDate(creditNote.creditDate),
        'Reference': creditNote.reason,
        'LineAmountTypes': 'Inclusive',
        'LineItems': [
          {
            'Description': creditNote.reason ?? 'Credit note',
            'Quantity': '1',
            'UnitAmount': _xeroAmount(creditNote.totalAmount),
            'LineAmount': _xeroAmount(creditNote.totalAmount),
          },
        ],
      });
      if (response.statusCode < 200 || response.statusCode >= 300) {
        continue;
      }
      final externalId = _firstExternalId(response.body, 'CreditNoteID');
      if (externalId == null) {
        continue;
      }
      await DaoCreditNote().markExternal(
        creditNote: creditNote,
        externalCreditNoteId: externalId,
      );
      final allocations = await DaoCreditAllocation().getByCreditNoteId(
        creditNote.id,
      );
      for (final allocation in allocations) {
        if (allocation.externalAllocationId != null) {
          continue;
        }
        final allocatedInvoice = await _daoInvoice.getById(
          allocation.invoiceId,
        );
        if (allocatedInvoice?.externalInvoiceId == null) {
          continue;
        }
        final allocationResponse = await _xeroClient.allocateCreditNote(
          externalId,
          {
            'Invoice': {'InvoiceID': allocatedInvoice!.externalInvoiceId},
            'Amount': _xeroAmount(allocation.amount),
            'Date': _xeroDate(allocation.allocatedDate),
          },
        );
        if (allocationResponse.statusCode >= 200 &&
            allocationResponse.statusCode < 300) {
          await DaoCreditAllocation().update(
            allocation.copyWith(
              externalAllocationId:
                  _firstExternalId(allocationResponse.body, 'AllocationID') ??
                  'xero',
            ),
          );
        }
      }
      pushed += 1;
    }
    return pushed;
  }

  bool _isConfigurationWarning(Object error) =>
      error is InvoiceException &&
      error.message.contains('The Xero credentials are not set');

  Future<_RemoteInvoiceState?> _loadRemoteState(Invoice invoice) async {
    final externalId = invoice.externalInvoiceId;
    if (externalId == null || externalId.isEmpty) {
      return null;
    }

    final response = await _xeroClient.getInvoice(externalId);
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

    final status = ((remote['Status'] as String?) ?? '').trim().toUpperCase();
    final amountDue = _toDouble(remote['AmountDue']);
    final amountPaid = _toDouble(remote['AmountPaid']);
    final isPaid = status == 'PAID' || (amountDue <= 0 && amountPaid > 0);

    return _RemoteInvoiceState(
      externalSyncStatus: switch (status) {
        'DELETED' => InvoiceExternalSyncStatus.deleted,
        'VOIDED' => InvoiceExternalSyncStatus.voided,
        _ => InvoiceExternalSyncStatus.linked,
      },
      paidDate: isPaid
          ? _parseXeroDate(remote['FullyPaidOnDate']) ?? DateTime.now()
          : null,
      payments: _parsePayments(remote['Payments']),
      creditNotes: _parseCreditNotes(remote['CreditNotes']),
    );
  }

  Future<int> _importPayments(
    Invoice invoice,
    List<_RemotePayment> payments,
  ) async {
    var imported = 0;
    for (final payment in payments) {
      final existing = await DaoDebtorPayment().getByExternalPaymentId(
        provider: 'xero',
        externalPaymentId: payment.externalId,
      );
      if (existing != null) {
        continue;
      }
      final debtorPayment = await _ledgerService.recordPayment(
        invoiceId: invoice.id,
        amount: payment.amount,
        paymentDate: payment.date,
        paymentMethod: 'Xero',
        reference: payment.reference,
        notes: payment.externalId,
      );
      await DaoDebtorPayment().update(
        DebtorPayment(
          id: debtorPayment.id,
          customerId: debtorPayment.customerId,
          contactId: debtorPayment.contactId,
          paymentDate: debtorPayment.paymentDate,
          amount: debtorPayment.amount,
          paymentMethod: debtorPayment.paymentMethod,
          reference: debtorPayment.reference,
          notes: debtorPayment.notes,
          externalPaymentId: payment.externalId,
          externalProvider: 'xero',
          createdDate: debtorPayment.createdDate,
          modifiedDate: debtorPayment.modifiedDate,
        ),
      );
      imported += 1;
    }
    return imported;
  }

  Future<int> _importCreditNotes(
    Invoice invoice,
    List<_RemoteCreditNote> creditNotes,
  ) async {
    var imported = 0;
    for (final creditNote in creditNotes) {
      final existing = await DaoCreditNote().getByExternalCreditNoteId(
        creditNote.externalId,
      );
      if (existing != null) {
        continue;
      }
      final created = await _ledgerService.createCreditNote(
        invoiceId: invoice.id,
        amount: creditNote.amount,
        reason: creditNote.reference ?? 'Xero credit note',
        creditDate: creditNote.date,
      );
      await DaoCreditNote().update(
        CreditNote(
          id: created.id,
          customerId: created.customerId,
          contactId: created.contactId,
          jobId: created.jobId,
          relatedInvoiceId: created.relatedInvoiceId,
          creditDate: created.creditDate,
          totalAmount: created.totalAmount,
          creditNoteNum: created.creditNoteNum,
          externalCreditNoteId: creditNote.externalId,
          status: created.status,
          reason: created.reason,
          createdDate: created.createdDate,
          modifiedDate: created.modifiedDate,
        ),
      );
      imported += 1;
    }
    return imported;
  }

  List<_RemotePayment> _parsePayments(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map((payment) {
          final externalId = payment['PaymentID'] as String?;
          final amount = _moneyFromXeroAmount(payment['Amount']);
          if (externalId == null || externalId.isEmpty || !amount.isPositive) {
            return null;
          }
          return _RemotePayment(
            externalId: externalId,
            amount: amount,
            date: _parseXeroDate(payment['Date']) ?? DateTime.now(),
            reference: payment['Reference'] as String?,
          );
        })
        .nonNulls
        .toList();
  }

  List<_RemoteCreditNote> _parseCreditNotes(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map((creditNote) {
          final externalId = creditNote['CreditNoteID'] as String?;
          final amount = _moneyFromXeroAmount(
            creditNote['Total'] ?? creditNote['AppliedAmount'],
          );
          if (externalId == null || externalId.isEmpty || !amount.isPositive) {
            return null;
          }
          return _RemoteCreditNote(
            externalId: externalId,
            amount: amount,
            date: _parseXeroDate(creditNote['Date']) ?? DateTime.now(),
            reference:
                creditNote['CreditNoteNumber'] as String? ??
                creditNote['Reference'] as String?,
          );
        })
        .nonNulls
        .toList();
  }

  Money _moneyFromXeroAmount(dynamic value) =>
      MoneyEx.fromInt((_toDouble(value) * 100).round());

  String _xeroAmount(Money amount) => amount.format('0.##');

  String _xeroDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String? _firstExternalId(String body, String fieldName) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final direct = decoded[fieldName];
      if (direct is String && direct.isNotEmpty) {
        return direct;
      }
      for (final value in decoded.values) {
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is Map<String, dynamic>) {
            final nested = first[fieldName];
            if (nested is String && nested.isNotEmpty) {
              return nested;
            }
          }
        }
      }
    }
    return null;
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

class _RemoteInvoiceState {
  final InvoiceExternalSyncStatus externalSyncStatus;
  final DateTime? paidDate;
  final List<_RemotePayment> payments;
  final List<_RemoteCreditNote> creditNotes;

  const _RemoteInvoiceState({
    required this.externalSyncStatus,
    required this.paidDate,
    required this.payments,
    required this.creditNotes,
  });
}

class _RemotePayment {
  final String externalId;
  final Money amount;
  final DateTime date;
  final String? reference;

  const _RemotePayment({
    required this.externalId,
    required this.amount,
    required this.date,
    this.reference,
  });
}

class _RemoteCreditNote {
  final String externalId;
  final Money amount;
  final DateTime date;
  final String? reference;

  const _RemoteCreditNote({
    required this.externalId,
    required this.amount,
    required this.date,
    this.reference,
  });
}
