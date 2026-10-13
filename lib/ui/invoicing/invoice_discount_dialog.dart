import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';

import '../../util/dart/money_ex.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/hmb_button.dart';
import '../widgets/layout/hmb_form_section.dart';

class InvoiceDiscountRequest {
  final String description;
  final Money amount;

  const InvoiceDiscountRequest({
    required this.description,
    required this.amount,
  });
}

class InvoiceDiscountDialog extends StatefulWidget {
  const InvoiceDiscountDialog({super.key});

  @override
  State<InvoiceDiscountDialog> createState() => _InvoiceDiscountDialogState();
}

class _InvoiceDiscountDialogState extends State<InvoiceDiscountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController(text: 'Discount');
  final _amount = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add Discount'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: HMBFormSection(
          children: [
            HMBTextField(controller: _description, labelText: 'Description'),
            HMBTextField(
              controller: _amount,
              labelText: 'Amount',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => MoneyEx.tryParse(value ?? '').isPositive
                  ? null
                  : 'Enter an amount greater than zero.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      HMBCancelButton(onPressed: () => Navigator.of(context).pop()),
      HMBButtonPrimary(
        label: 'Add',
        hint: 'Add the discount to this invoice',
        onPressed: () {
          if (!_formKey.currentState!.validate()) {
            return;
          }
          Navigator.of(context).pop(
            InvoiceDiscountRequest(
              description: _description.text.trim().isEmpty
                  ? 'Discount'
                  : _description.text.trim(),
              amount: MoneyEx.tryParse(_amount.text),
            ),
          );
        },
      ),
    ],
  );
}
