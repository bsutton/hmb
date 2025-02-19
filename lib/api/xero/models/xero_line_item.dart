import 'package:money2/money2.dart';

class XeroLineItem {
  XeroLineItem({
    required this.description,
    required this.quantity,
    required this.unitAmount,
    required this.lineTotal,
    required this.accountCode,
    required this.itemCode,
  });
  final String description;
  final Fixed quantity;
  final Money unitAmount;
  final Money lineTotal;
  final String accountCode;
  final String itemCode;

  Map<String, dynamic> toJson() => {
    'Description': description,
    'Quantity': quantity.toString(),
    'UnitAmount': unitAmount.format('0.##'),
    'LineAmount': lineTotal.format('0.##'),
    'AccountCode': accountCode,
    'ItemCode': itemCode,
  };
}
