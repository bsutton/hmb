import '../xero_api.dart';
import 'models.dart';

class Invoice {
  Invoice({
    required this.type,
    required this.contact,
    required this.lineItems,
    required this.date,
    required this.dueDate,
    required this.lineAmountTypes,
  });
  final String type;
  final Contact contact;
  final List<LineItem> lineItems;
  final DateTime date;
  final DateTime dueDate;
  final String lineAmountTypes;

  Map<String, dynamic> toJson() => {
        'Type': type,
        'Contact': contact.toJson(),
        'LineItems': lineItems.map((item) => item.toJson()).toList(),
        'Date': date.toIso8601String(),
        'DueDate': dueDate.toIso8601String(),
        'LineAmountTypes': lineAmountTypes,
      };

  static Future<void> create(String? accessToken) async {
    if (accessToken == null) {
      print('No access token found. Please authenticate first.');
      return;
    }

    final api = XeroApi(accessToken);
    final contact = Contact(name: 'Sample Customer');
    final lineItem = LineItem(
      description: 'Sample Item',
      quantity: 1,
      unitAmount: 100,
      accountCode: '200',
    );
    final invoice = Invoice(
      type: 'ACCREC',
      contact: contact,
      lineItems: [lineItem],
      date: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 30)),
      lineAmountTypes: 'Exclusive',
    );

    final response = await api.createInvoice(invoice);
    if (response.statusCode == 200) {
      print('Invoice created successfully');
    } else {
      print('Failed to create invoice: ${response.body}');
    }
  }
}
