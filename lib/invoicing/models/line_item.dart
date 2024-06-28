class LineItem {
  LineItem({
    required this.description,
    required this.quantity,
    required this.unitAmount,
    required this.accountCode,
  });
  final String description;
  final double quantity;
  final double unitAmount;
  final String accountCode;

  Map<String, dynamic> toJson() => {
        'Description': description,
        'Quantity': quantity,
        'UnitAmount': unitAmount,
        'AccountCode': accountCode,
      };
}
