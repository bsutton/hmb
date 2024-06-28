import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../entity/invoice_line.dart';

class EditInvoiceLineDialog extends StatefulWidget {
  const EditInvoiceLineDialog({required this.line, super.key});
  final InvoiceLine line;

  @override
  // ignore: library_private_types_in_public_api
  _EditInvoiceLineDialogState createState() => _EditInvoiceLineDialogState();
}

class _EditInvoiceLineDialogState extends State<EditInvoiceLineDialog> {
  late TextEditingController _quantityController;
  late TextEditingController _unitPriceController;
  late TextEditingController _percentageController;

  @override
  void initState() {
    super.initState();
    _quantityController =
        TextEditingController(text: widget.line.quantity.toString());
    _unitPriceController =
        TextEditingController(text: widget.line.unitPrice.toString());
    _percentageController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit Invoice Line'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _unitPriceController,
              decoration: const InputDecoration(labelText: 'Unit Price (AUD)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _percentageController,
              decoration: const InputDecoration(labelText: 'Increase %'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final quantity = Fixed.parse(_quantityController.text);
              final unitPrice =
                  Money.parse(_unitPriceController.text, isoCode: 'AUD');
              final percentage =
                  double.tryParse(_percentageController.text) ?? 0.0;
              final newUnitPrice = unitPrice * (1 + percentage / 100);
              final lineTotal = newUnitPrice.multiplyByFixed(quantity);

              final updatedLine = widget.line.copyWith(
                quantity: quantity,
                unitPrice: newUnitPrice,
                lineTotal: lineTotal,
              );

              Navigator.of(context).pop(updatedLine);
            },
            child: const Text('Save'),
          ),
        ],
      );
}
