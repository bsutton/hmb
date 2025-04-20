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

class XeroException extends HMBException {
  XeroException(super.message);
}

class InvalidPathException extends HMBException {
  InvalidPathException(super.message);
}

class IntegrationDisabledExcpetion extends HMBException {
  IntegrationDisabledExcpetion(super.message);
}
