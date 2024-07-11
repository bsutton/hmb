import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../entity/quote_line.dart';

class EditQuoteLineDialog extends StatefulWidget {
  const EditQuoteLineDialog({required this.line, super.key});
  final QuoteLine line;

  @override
  // ignore: library_private_types_in_public_api
  _EditQuoteLineDialogState createState() => _EditQuoteLineDialogState();
}

class _EditQuoteLineDialogState extends State<EditQuoteLineDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  late TextEditingController _unitPriceController;
  late LineStatus _status;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.line.description);
    _quantityController =
        TextEditingController(text: widget.line.quantity.toString());
    _unitPriceController =
        TextEditingController(text: widget.line.unitPrice.toString());
    _status = widget.line.status;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit Quote Line'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _unitPriceController,
                decoration: const InputDecoration(labelText: 'Unit Price'),
                keyboardType: TextInputType.number,
              ),
              DropdownButton<LineStatus>(
                value: _status,
                onChanged: (newValue) {
                  setState(() {
                    _status = newValue!;
                  });
                },
                items: LineStatus.values
                    .map((status) => DropdownMenuItem<LineStatus>(
                          value: status,
                          child: Text(status.toString().split('.').last),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () {
              final quantity = Fixed.parse(_quantityController.text);
              final unitPrice =
                  Money.parse(_unitPriceController.text, isoCode: 'AUD');
              final updatedLine = widget.line.copyWith(
                description: _descriptionController.text,
                quantity: quantity,
                unitPrice: unitPrice,
                lineTotal: unitPrice.multiplyByFixed(quantity),
                status: _status,
              );
              Navigator.of(context).pop(updatedLine);
            },
          ),
        ],
      );
}
