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

// lib/src/ui/dashboard/billing_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../../api/xero/xero_invoice_payment_sync_service.dart';
import '../../../../dao/dao.g.dart';
import '../../../../entity/entity.g.dart';
import '../../../../util/flutter/flutter_util.g.dart';
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/widgets.g.dart';
import '../dashboard.dart';
import '../dashlet_card.dart';
import '../sync_warnings.dart';
import 'invoices.dart';
import 'receipt.dart';

class AccountingDashboardPage extends StatefulWidget {
  const AccountingDashboardPage({super.key});

  @override
  State<AccountingDashboardPage> createState() =>
      _AccountingDashboardPageState();
}

class _AccountingDashboardPageState extends State<AccountingDashboardPage> {
  var _syncing = false;

  @override
  Widget build(BuildContext context) => DashboardPage(
    title: 'Accounting',
    header: _header(),
    dashlets: [
      const ReceiptDashlet(),
      DashletCard<void>.route(
        label: 'Estimator',
        hint:
            'Create estimates for a Job by adding Tasks, Labour and Materials',
        icon: Icons.calculate,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/accounting/estimator',
        valueBuilder: (_, _) => const SizedBox.shrink(),
      ),
      DashletCard<String>.route(
        label: 'Quotes',
        hint: 'Quote a Job based on an Estimate',
        icon: Icons.format_quote,
        value: getQuoteValue,
        route: '/home/accounting/quotes',
      ),
      DashletCard<int>.route(
        label: 'To Be Invoiced',
        hint: 'List of Jobs that have unbilled hours',
        icon: Icons.attach_money,
        value: getYetToBeInvoiced,
        route: '/home/accounting/to_be_invoiced',
      ),
      const InvoiceDashlet(),
      DashletCard<void>.route(
        label: 'Customer Payments',
        hint: 'Record, allocate and review customer payments',
        icon: Icons.payments,
        value: () async => const DashletValue(null),
        route: '/home/accounting/payments',
        valueBuilder: (_, _) => const SizedBox.shrink(),
      ),
      DashletCard<void>.route(
        label: 'Milestones',
        hint: 'Create and Invoice Milestone Payments for Fixed price Jobs',
        icon: Icons.flag,
        value: () async => const DashletValue(null),
        route: '/home/accounting/milestones',
        valueBuilder: (_, _) => const SizedBox.shrink(),
      ),
      DashletCard<void>.route(
        label: 'Reports',
        hint: 'Export accountant-ready reports for tax time',
        icon: Icons.assessment,
        value: () async => const DashletValue(null),
        route: '/home/accounting/reports',
        valueBuilder: (_, _) => const SizedBox.shrink(),
      ),
    ],
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: HMBButton.withIcon(
            label: _syncing ? 'Syncing' : 'Sync',
            hint: 'Refresh invoice payment status from Xero',
            icon: _syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            enabled: !_syncing,
            onPressed: _syncAccounting,
          ),
        ),
        JuneBuilder(
          AccountingSyncWarningState.new,
          builder: (_) {
            final warning = June.getState<AccountingSyncWarningState>(
              AccountingSyncWarningState.new,
            ).warning;
            if (warning == null) {
              return const HMBEmpty();
            }
            return FutureBuilder<void>(
              future: June.getState<AccountingSyncWarningState>(
                AccountingSyncWarningState.new,
              ).clearIfIntegrationDisabled(),
              builder: (context, snapshot) {
                final currentWarning =
                    June.getState<AccountingSyncWarningState>(
                      AccountingSyncWarningState.new,
                    ).warning;
                if (currentWarning == null) {
                  return const HMBEmpty();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  child: Surface(
                    rounded: true,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber,
                        ),
                        const HMBSpacer(width: true),
                        Expanded(
                          child: Text(
                            currentWarning.details,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    ),
  );

  Future<void> _syncAccounting() async {
    setState(() => _syncing = true);
    var syncFailed = false;
    try {
      final updated = await XeroInvoicePaymentSyncService().sync(
        force: true,
        onError: (error, _) {
          syncFailed = true;
          June.getState<AccountingSyncWarningState>(
            AccountingSyncWarningState.new,
          ).showWarning(
            'Xero invoice payment sync failed',
            formatAccountingSyncWarning(error),
          );
        },
      );
      if (!syncFailed) {
        June.getState<AccountingSyncWarningState>(
          AccountingSyncWarningState.new,
        ).clearWarning();
        June.getState<DashboardReloaded>(DashboardReloaded.new).setState();
        HMBToast.info(
          updated == 1
              ? '1 accounting item synced'
              : '$updated accounting items synced',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<DashletValue<String>> getQuoteValue() async {
    final quotes = await DaoQuote().getAll();
    var total = MoneyEx.zero;
    for (final q in quotes) {
      if (q.state == QuoteState.reviewing || q.state == QuoteState.sent) {
        total += q.totalAmount;
      }
    }
    return DashletValue(total.format('S#'));
  }

  Future<DashletValue<int>> getYetToBeInvoiced() async {
    final jobs = await DaoJob().readyToBeInvoiced(null);
    final count = jobs.length;
    var total = MoneyEx.zero;
    for (final job in jobs) {
      final hourlyRate = job.hourlyRate;
      final statistics = await DaoJob().getJobStatistics(job);
      total +=
          statistics.completedMaterialCost +
          (hourlyRate!.multiplyByFixed(statistics.workedHours));
    }
    return DashletValue(count, total.format('S#'));
  }
}
