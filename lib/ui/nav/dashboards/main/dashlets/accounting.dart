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

// lib/src/ui/dashboard/billing_dashlet.dart
import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../accounting/invoices.dart';
import '../../dashlet_card.dart';
import '../../sync_warnings.dart';

/// Dashlet for Billing sub-dashboard
class AccountingDashlet extends StatelessWidget {
  const AccountingDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<InvoiceCountSummary>.route(
    label: 'Accounting',
    hint: 'Create Estimates, Quotes and Invoices and scan Receipts',
    icon: Icons.account_balance_wallet,
    value: _getInvoiceCounts,
    route: '/home/accounting',
    valueBuilder: (context, dv) => JuneBuilder(
      AccountingSyncWarningState.new,
      builder: (_) {
        final warning = June.getState<AccountingSyncWarningState>(
          AccountingSyncWarningState.new,
        ).warning;
        if (warning != null) {
          return FutureBuilder<void>(
            future: June.getState<AccountingSyncWarningState>(
              AccountingSyncWarningState.new,
            ).clearIfIntegrationDisabled(),
            builder: (context, snapshot) {
              final currentWarning = June.getState<AccountingSyncWarningState>(
                AccountingSyncWarningState.new,
              ).warning;
              if (currentWarning == null) {
                return buildInvoiceCountSummary(context, dv.value!);
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
                  Text(
                    'Warning',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          );
        }
        return buildInvoiceCountSummary(context, dv.value!);
      },
    ),
  );

  Future<DashletValue<InvoiceCountSummary>> _getInvoiceCounts() async =>
      DashletValue(await loadInvoiceCountSummary());
}
