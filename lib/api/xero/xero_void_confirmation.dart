/// Check the identity, status and settlement details of one Xero invoice.
String? xeroVoidProblem(
  Object? body,
  String id, {
  bool allowMissingTotals = false,
}) {
  if (body is! Map<String, dynamic> || body['Invoices'] is! List<dynamic>) {
    return 'Xero returned an unexpected invoice response.';
  }
  final invoices = body['Invoices'] as List<dynamic>;
  if (invoices.length != 1 || invoices.single is! Map<String, dynamic>) {
    return 'Xero did not return the linked invoice in this organisation.';
  }
  final invoice = invoices.single as Map<String, dynamic>;
  final returnedId = invoice['InvoiceID'];
  if (id.trim().isEmpty ||
      returnedId is! String ||
      returnedId.trim().toLowerCase() != id.trim().toLowerCase()) {
    return 'The invoice returned by Xero does not match the HMB link.';
  }
  if (invoice['HasErrors'] == true ||
      !_emptyOrAbsent(invoice['ValidationErrors'])) {
    return 'Xero returned a validation error for the invoice.';
  }
  final status = invoice['Status'];
  if (status is! String || status.trim().toUpperCase() != 'VOIDED') {
    return 'Xero reports the invoice status as ${status ?? "unknown"}.';
  }
  for (final key in [
    'Payments',
    'CreditNotes',
    'Prepayments',
    'Overpayments',
  ]) {
    if (!_emptyOrAbsent(invoice[key])) {
      return 'Xero returned $key entries for this invoice.';
    }
  }
  for (final entry in const {
    'AmountPaid': ['Payments'],
    'AmountCredited': ['CreditNotes', 'Prepayments', 'Overpayments'],
  }.entries) {
    final amount = invoice[entry.key];
    if (amount == 0 || (amount is String && num.tryParse(amount.trim()) == 0)) {
      continue;
    }
    if (!invoice.containsKey(entry.key)) {
      if (allowMissingTotals ||
          entry.value.every((key) => invoice[key] is List)) {
        continue;
      }
      return 'Xero omitted ${entry.key} and its complete allocation details.';
    }
    if (amount is num || (amount is String && num.tryParse(amount) != null)) {
      return 'Xero reports ${entry.key} as $amount for this invoice.';
    }
    return 'Xero returned an unreadable ${entry.key} for this invoice.';
  }
  return null;
}

/// Only a missing total on an otherwise valid void warrants a second read.
bool needsXeroVoidLookup(Object? body, String id) =>
    xeroVoidProblem(body, id) != null &&
    xeroVoidProblem(body, id, allowMissingTotals: true) == null;

bool _emptyOrAbsent(Object? value) =>
    value == null || (value is List && value.isEmpty);
