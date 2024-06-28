class HMBException implements Exception {
  HMBException(this.message);

  String message;

  @override
  String toString() => message;
}

class BackupException extends HMBException {
  BackupException(super.message);
}

class InvoiceException extends HMBException {
  InvoiceException(super.message);
}
