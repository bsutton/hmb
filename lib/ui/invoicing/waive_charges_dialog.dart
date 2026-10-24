import 'package:material_ui/material_ui.dart';

import '../../dao/billing_service.dart';
import '../../util/dart/money_ex.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/widgets.g.dart';

class WaiveChargesDialog extends StatefulWidget {
  final List<BillingCandidate> charges;
  const WaiveChargesDialog({required this.charges, super.key});

  @override
  State<WaiveChargesDialog> createState() => _WaiveChargesDialogState();
}

class _WaiveChargesDialogState extends State<WaiveChargesDialog> {
  final _reason = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String get _total => widget.charges
      .fold(MoneyEx.zero, (sum, charge) => sum + charge.amount)
      .toString();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Waive selected charges?'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: HMBFormSection(
          children: [
            for (final charge in widget.charges)
              Text('${charge.description} — ${charge.amount}'),
            Text('Total: $_total'),
            const Text(
              'These charges will no longer be offered for invoicing. '
              'The work and your reason are retained. You can restore them '
              'from Waived charges.',
            ),
            HMBTextField(
              controller: _reason,
              labelText: 'Reason',
              maxLines: 3,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a reason for waiving these charges.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      HMBCancelButton(onPressed: () => Navigator.of(context).pop()),
      HMBButtonPrimary(
        label: 'Waive charges',
        hint: 'Record this decision without creating an invoice',
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.of(context).pop(_reason.text.trim());
          }
        },
      ),
    ],
  );
}
