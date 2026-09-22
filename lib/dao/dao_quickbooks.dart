import 'package:uuid/uuid.dart';

import '../database/management/database_helper.dart';
import '../entity/quickbooks_settings.dart';

class DaoQuickBooks {
  Future<QuickBooksSettings> settings() async => QuickBooksSettings.fromMap(
    (await DatabaseHelper().database.query('quickbooks_settings')).single,
  );

  Future<void> saveSettings(QuickBooksSettings settings) async {
    settings.validateAuth();
    await DatabaseHelper().database.update(
      'quickbooks_settings',
      settings.toMap(),
      where: 'id = 1',
    );
  }

  Future<Map<String, Object?>?> exportFor(int invoiceId) async =>
      (await DatabaseHelper().database.query(
        'quickbooks_invoice_export',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      )).firstOrNull;

  Future<Map<String, Object?>> prepareExport({
    required int invoiceId,
    required String realmId,
    required bool sandbox,
    required String payload,
  }) async => await DatabaseHelper().database.transaction((txn) async {
    final existing = (await txn.query(
      'quickbooks_invoice_export',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    )).firstOrNull;
    if (existing != null) {
      if (existing['realm_id'] != realmId ||
          existing['sandbox'] != (sandbox ? 1 : 0) ||
          existing['payload_json'] != payload) {
        throw const FormatException(
          'This invoice has an earlier QuickBooks '
          'export attempt with different settings or content. Reconcile it '
          'in QuickBooks before making another export.',
        );
      }
      return existing;
    }
    final values = <String, Object?>{
      'invoice_id': invoiceId,
      'realm_id': realmId,
      'sandbox': sandbox ? 1 : 0,
      'request_id': const Uuid().v4(),
      'payload_json': payload,
    };
    await txn.insert('quickbooks_invoice_export', values);
    return values;
  });

  Future<void> completeExport(
    int invoiceId,
    Map<String, dynamic> invoice,
  ) async {
    await DatabaseHelper().database.update(
      'quickbooks_invoice_export',
      {
        'external_id': invoice['Id'] as String,
        'external_number': invoice['DocNumber'] as String?,
        'remote_total': invoice['TotalAmt'].toString(),
      },
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
  }
}
