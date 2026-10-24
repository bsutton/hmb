import 'package:money2/money2.dart';

import '../util/dart/money_ex.dart';

/// An auditable decision not to bill a particular version of a charge.
class BillingWaiver {
  final int id;
  final String sourceKey;
  final String sourceHash;
  final String description;
  final Money amount;
  final String reason;
  final DateTime waivedDate;
  final DateTime? restoredDate;

  BillingWaiver.fromMap(Map<String, Object?> row)
    : id = row['id']! as int,
      sourceKey = '${row['source_type']}:${row['source_id']}',
      sourceHash = row['source_hash']! as String,
      description = row['description']! as String,
      amount = MoneyEx.fromInt(row['amount']! as int),
      reason = row['reason']! as String,
      waivedDate = DateTime.parse(row['waived_date']! as String),
      restoredDate = row['restored_date'] == null
          ? null
          : DateTime.parse(row['restored_date']! as String);
}
