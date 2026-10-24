import 'invoice_details.dart';

/// UI eligibility only: ledger calculations and persistence remain in the DAOs.
class InvoiceEditorActions {
  final InvoiceDetails details;

  const InvoiceEditorActions(this.details);

  bool get readOnly => details.invoice.isExternallyDeletedOrVoided;

  bool get hasLedgerActivity =>
      details.ledgerHistory.isNotEmpty ||
      details.ledger.paid.isNonZero ||
      details.ledger.credited.isNonZero ||
      details.ledger.adjusted.isNonZero;

  /// Legacy/deposit invoices can have financial activity before being sent.
  bool get financiallyActive =>
      details.invoice.sent || hasLedgerActivity || details.invoice.paid;

  bool get canEdit =>
      !readOnly && !details.invoice.isUploaded() && !financiallyActive;

  bool get canAllocate =>
      !readOnly &&
      financiallyActive &&
      details.ledger.isOutstanding &&
      details.invoice.isManagedLocally;

  /// Corrections must remain reachable after settlement to fix mistakes.
  bool get canAdjust =>
      !readOnly && financiallyActive && details.invoice.isManagedLocally;

  bool get canWriteOff => canAdjust && details.ledger.isOutstanding;

  bool get canVoid =>
      !readOnly &&
      details.invoice.canVoid &&
      details.ledger.isOutstanding &&
      !hasLedgerActivity;

  bool get hasMoreActions => canAdjust || canWriteOff || canVoid;

  bool get hasPaymentActions => canAllocate || hasMoreActions;
}
