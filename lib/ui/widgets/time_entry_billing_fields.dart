import 'package:material_ui/material_ui.dart';

import 'hmb_toggle.dart';
import 'layout/layout.g.dart';

class TimeEntryBillingFields extends StatelessWidget {
  final bool billable;
  final bool showOnInvoice;
  final bool locked;
  final ValueChanged<bool> onBillableChanged;
  final ValueChanged<bool> onShowOnInvoiceChanged;

  const TimeEntryBillingFields({
    required this.billable,
    required this.showOnInvoice,
    required this.locked,
    required this.onBillableChanged,
    required this.onShowOnInvoiceChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) => locked
      ? const Text(
          'Billing options are locked while this time is on an invoice.',
        )
      : HMBFormSection(
          children: [
            HMBToggle(
              label: 'Billable time',
              hint: 'Charge for this time',
              initialValue: billable,
              onToggled: onBillableChanged,
            ),
            if (!billable) ...[
              HMBToggle(
                label: 'Show on invoice',
                hint: 'Include a no-charge line when invoicing this task',
                initialValue: showOnInvoice,
                onToggled: onShowOnInvoiceChanged,
              ),
              const Text(
                'Time remains in your records. If shown on an invoice, '
                'its charge is zero.',
              ),
            ],
          ],
        );
}
