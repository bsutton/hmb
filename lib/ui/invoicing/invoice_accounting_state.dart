import '../../api/external_accounting.dart';
import '../../dao/dao_quickbooks.dart';
import '../../dao/dao_system.dart';

/// Select a destination without silently choosing between two connections.
enum InvoiceAccountingDestination {
  none,
  disconnected,
  synced,
  snapshot,
  conflict,
}

class InvoiceAccountingState {
  final InvoiceAccountingDestination destination;
  final bool hasSnapshotAttempt;
  final bool snapshotComplete;

  const InvoiceAccountingState({
    required this.destination,
    this.hasSnapshotAttempt = false,
    this.snapshotComplete = false,
  });

  factory InvoiceAccountingState.resolve({
    required bool syncEnabled,
    required bool snapshotConnected,
    bool snapshotConfigured = false,
    bool hasSnapshotAttempt = false,
    bool snapshotComplete = false,
  }) => InvoiceAccountingState(
    destination: syncEnabled && (snapshotConnected || hasSnapshotAttempt)
        ? InvoiceAccountingDestination.conflict
        : syncEnabled
        ? InvoiceAccountingDestination.synced
        : snapshotConnected
        ? InvoiceAccountingDestination.snapshot
        : snapshotConfigured
        ? InvoiceAccountingDestination.disconnected
        : InvoiceAccountingDestination.none,
    hasSnapshotAttempt: hasSnapshotAttempt,
    snapshotComplete: snapshotComplete,
  );

  static Future<InvoiceAccountingState> load(int invoiceId) async {
    final syncEnabled = await ExternalAccounting().isEnabled();
    final credentials = await DaoSystem().getQuickBooksCredentials();
    final settings = await DaoQuickBooks().settings();
    final exported = await DaoQuickBooks().exportFor(invoiceId);
    return InvoiceAccountingState.resolve(
      syncEnabled: syncEnabled,
      snapshotConfigured: settings.clientId.trim().isNotEmpty,
      snapshotConnected:
          credentials.tokenJson != null && credentials.realmId != null,
      hasSnapshotAttempt: exported != null,
      snapshotComplete: exported?['external_id'] != null,
    );
  }

  bool get canUpload =>
      destination == InvoiceAccountingDestination.synced ||
      destination == InvoiceAccountingDestination.snapshot;

  String get explanation => switch (destination) {
    InvoiceAccountingDestination.none =>
      hasSnapshotAttempt
          ? 'An earlier accounting export exists. Reconnect the original '
                'accounting integration in settings to review it.'
          : 'Connect accounting in System > Integration to upload a copy. '
                'You can send this invoice without accounting.',
    InvoiceAccountingDestination.disconnected =>
      hasSnapshotAttempt
          ? 'An earlier accounting export exists. Reconnect the original '
                'integration to review its status before retrying upload.'
          : 'Accounting is configured but not connected. Reconnect in '
                'System > Integration to upload.',
    InvoiceAccountingDestination.conflict =>
      'More than one accounting destination is configured or this invoice '
          'has an earlier export. Review integration settings and the '
          'existing export before uploading.',
    InvoiceAccountingDestination.synced =>
      'Upload to the configured accounting provider. '
          'Upload is required before email while this integration is '
          'enabled. The connection is checked during upload.',
    InvoiceAccountingDestination.snapshot =>
      snapshotComplete
          ? 'An invoice snapshot was exported. Payments and later changes '
                'must be reconciled separately.'
          : hasSnapshotAttempt
          ? 'An earlier export was attempted. Review its status '
                'before retrying; '
                'reuse the same invoice and customer.'
          : 'Export an invoice snapshot. Payments and later changes must be '
                'reconciled separately.',
  };
}
