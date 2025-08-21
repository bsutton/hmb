/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

class HMBException implements Exception {
  final String message;

  HMBException(this.message);

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

class TaskMoveException extends HMBException {
  TaskMoveException(super.message);
}
