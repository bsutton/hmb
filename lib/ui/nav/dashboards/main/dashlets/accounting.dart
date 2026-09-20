/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
// lib/src/ui/dashboard/billing_dashlet.dart
import 'package:material_ui/material_ui.dart';

import '../../accounting/billing_attention_count.dart';
import '../../accounting/invoices.dart';
import '../../dashlet_card.dart';
import '../../sync_warnings.dart';

/// Dashlet for Billing sub-dashboard
class AccountingDashlet extends StatelessWidget {
  const AccountingDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>.route(
    label: 'Accounting',
    hint: 'Create Estimates, Quotes and Invoices and scan Receipts',
    icon: Icons.account_balance_wallet,
    value: () async => const DashletValue.empty(),
    route: '/home/accounting',
    valueBuilder: (context, dv) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BillingAttentionCount(),
        const SizedBox(height: 6),
        FutureBuilderEx<InvoiceCountSummary>(
          future: loadInvoiceCountSummary(),
          waitingBuilder: (_) => const Text('Updating invoices…'),
          errorBuilder: (_, error) => const Text('Invoice count unavailable'),
          builder: (context, summary) => _invoiceSummary(context, summary!),
        ),
      ],
    ),
  );

  Widget _invoiceSummary(
    BuildContext context,
    InvoiceCountSummary summary,
  ) => JuneBuilder(
    AccountingSyncWarningState.new,
    builder: (_) {
      final warning = June.getState<AccountingSyncWarningState>(
        AccountingSyncWarningState.new,
      ).warning;
      if (warning != null) {
        return FutureBuilderEx<void>(
          future: June.getState<AccountingSyncWarningState>(
            AccountingSyncWarningState.new,
          ).clearIfIntegrationDisabled(),
          waitingBuilder: (_) => const Text('Checking sync warning…'),
          errorBuilder: (_, error) => const Text('Accounting sync warning'),
          builder: (context, snapshot) {
            final currentWarning = June.getState<AccountingSyncWarningState>(
              AccountingSyncWarningState.new,
            ).warning;
            if (currentWarning == null) {
              return buildInvoiceCountSummary(context, summary);
            }
            return const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text('Warning', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            );
          },
        );
      }
      return buildInvoiceCountSummary(context, summary);
    },
  );
}
