import 'models.dart';

class XeroInvoice {
  XeroInvoice({
    required this.reference,
    required this.type,
    required this.contact,
    required this.lineItems,
    required this.issueDate,
    required this.dueDate,
    required this.lineAmountTypes,
  });
  final String reference;
  final String type;
  final XeroContact contact;
  final List<XeroLineItem> lineItems;
  final DateTime issueDate;
  final DateTime dueDate;
  final String lineAmountTypes;

  /// toJson
  Map<String, dynamic> toJson() => {
        'Reference': reference,
        'Type': type,
        'Contact': contact.toJson(),
        'LineItems': lineItems.map((item) => item.toJson()).toList(),
        'Date': issueDate.toIso8601String(),
        'DueDate': dueDate.toIso8601String(),
        'LineAmountTypes': lineAmountTypes,
      };

  // /// Send an invoice to Xero
  // static Future<void> create(XeroApi api, XeroInvoice invoice) async {

  //   final response = await api.createInvoice(invoice);
  //   if (response.statusCode == 200) {
  //     print('Invoice created successfully');
  //   } else {
  //     print('Failed to create invoice: ${response.body}');
  //   }
  // }
}
