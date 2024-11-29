import '../../../util/local_date.dart';
import 'xero_contact.dart';
import 'xero_line_item.dart';

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
  final LocalDate issueDate;
  final LocalDate dueDate;
  final String lineAmountTypes;

  /// toJson
  Map<String, dynamic> toJson() => {
        'Reference': reference,
        'Type': type,
        'Contact': contact.toJson(),
        'LineItems': lineItems.map((item) => item.toJson()).toList(),
        'Date': const LocalDateConverter().toJson(issueDate),
        'DueDate': const LocalDateConverter().toJson(dueDate),
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
