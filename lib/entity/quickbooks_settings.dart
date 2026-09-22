class QuickBooksSettings {
  final String clientId;
  final String redirectUri;
  final bool sandbox;
  final String itemId;
  final String taxableCode;
  final String exemptCode;
  final bool usTaxModel;
  final String transactionTaxCode;

  const QuickBooksSettings({
    this.clientId = '',
    this.redirectUri = '',
    this.sandbox = true,
    this.itemId = '',
    this.taxableCode = '',
    this.exemptCode = '',
    this.usTaxModel = false,
    this.transactionTaxCode = '',
  });

  factory QuickBooksSettings.fromMap(Map<String, Object?> row) =>
      QuickBooksSettings(
        clientId: row['client_id'] as String? ?? '',
        redirectUri: row['redirect_uri'] as String? ?? '',
        sandbox: row['sandbox'] == 1,
        itemId: row['item_id'] as String? ?? '',
        taxableCode: row['taxable_code'] as String? ?? '',
        exemptCode: row['exempt_code'] as String? ?? '',
        usTaxModel: row['us_tax_model'] == 1,
        transactionTaxCode: row['transaction_tax_code'] as String? ?? '',
      );

  Map<String, Object?> toMap() => {
    'id': 1,
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'sandbox': sandbox ? 1 : 0,
    'item_id': itemId,
    'taxable_code': taxableCode,
    'exempt_code': exemptCode,
    'us_tax_model': usTaxModel ? 1 : 0,
    'transaction_tax_code': transactionTaxCode,
  };

  void validateAuth() {
    final uri = Uri.tryParse(redirectUri);
    final loopback =
        sandbox &&
        uri?.scheme == 'http' &&
        (uri?.host == 'localhost' || uri?.host == '127.0.0.1');
    if (clientId.isEmpty ||
        uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' && !loopback)) {
      throw const FormatException(
        'Enter the registered client ID and HTTPS callback '
        '(sandbox also accepts localhost HTTP).',
      );
    }
  }
}
