/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:money2/money2.dart';

import 'entity.dart';

enum DebtorTransactionType {
  invoice(0),
  creditNote(1),
  payment(2),
  adjustment(3),
  writeOff(4),
  openingBalance(5),
  reversal(6);

  final int ordinal;
  const DebtorTransactionType(this.ordinal);

  static DebtorTransactionType fromOrdinal(int? value) =>
      DebtorTransactionType.values.firstWhere(
        (type) => type.ordinal == value,
        orElse: () => DebtorTransactionType.invoice,
      );
}

class DebtorTransaction extends Entity<DebtorTransaction> {
  int? debtorCustomerId;
  int? debtorContactId;
  int? jobId;
  DebtorTransactionType transactionType;
  String sourceTable;
  int sourceId;
  DateTime transactionDate;
  Money amount;
  Money taxAmount;
  String? description;

  DebtorTransaction({
    required super.id,
    required this.debtorCustomerId,
    required this.debtorContactId,
    required this.jobId,
    required this.transactionType,
    required this.sourceTable,
    required this.sourceId,
    required this.transactionDate,
    required this.amount,
    required this.taxAmount,
    required super.createdDate,
    required super.modifiedDate,
    this.description,
  }) : super();

  DebtorTransaction.forInsert({
    required this.debtorCustomerId,
    required this.debtorContactId,
    required this.jobId,
    required this.transactionType,
    required this.sourceTable,
    required this.sourceId,
    required this.transactionDate,
    required this.amount,
    required this.taxAmount,
    this.description,
  }) : super.forInsert();

  factory DebtorTransaction.fromMap(Map<String, dynamic> map) =>
      DebtorTransaction(
        id: map['id'] as int,
        debtorCustomerId: map['debtor_customer_id'] as int?,
        debtorContactId: map['debtor_contact_id'] as int?,
        jobId: map['job_id'] as int?,
        transactionType: DebtorTransactionType.fromOrdinal(
          map['transaction_type'] as int?,
        ),
        sourceTable: map['source_table'] as String,
        sourceId: map['source_id'] as int,
        transactionDate: DateTime.parse(map['transaction_date'] as String),
        amount: Money.fromInt(map['amount'] as int, isoCode: 'AUD'),
        taxAmount: Money.fromInt(map['tax_amount'] as int, isoCode: 'AUD'),
        description: map['description'] as String?,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'debtor_customer_id': debtorCustomerId,
    'debtor_contact_id': debtorContactId,
    'job_id': jobId,
    'transaction_type': transactionType.ordinal,
    'source_table': sourceTable,
    'source_id': sourceId,
    'transaction_date': transactionDate.toIso8601String(),
    'amount': amount.minorUnits.toInt(),
    'tax_amount': taxAmount.minorUnits.toInt(),
    'description': description,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
