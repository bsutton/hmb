// lib/src/ui/dashboard/dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_invoice.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_job_activity.dart';
import '../../dao/dao_quote.dart';
import '../../dao/dao_supplier.dart';
import '../../dao/dao_task_item.dart';
import '../../entity/job_activity.dart';
import '../../entity/quote.dart';
import '../../util/app_title.dart';
import '../../util/format.dart';
import '../../util/local_date.dart';
import '../../util/money_ex.dart';
import '../scheduling/schedule_page.dart';

typedef DashletValueBuilder<T> =
    Widget Function(BuildContext context, T? value);

class DashboardPage extends StatelessWidget {
  DashboardPage({super.key}) {
    setAppTitle('Dashboard');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildDashlet<int>(
            context,
            label: 'Jobs',
            icon: Icons.work,
            // ignore: discarded_futures
            future: getActiveJobs(),
            route: '/jobs',
          ),
          _buildDashlet<int>(
            context,
            label: 'Shopping',
            icon: Icons.shopping_cart,
            // ignore: discarded_futures
            future: getShoppingCount(),
            route: '/shopping',
          ),
          _buildDashlet<int>(
            context,
            label: 'Packing',
            icon: Icons.inventory_2,
            // ignore: discarded_futures
            future: getPackingCount(),
            route: '/packing',
          ),
          _buildDashlet<JobActivity?>(
            context,
            label: 'Next Job',
            icon: Icons.schedule,
            format: (activity) {
              if (activity == null) {
                return '—';
              }

              final date = formatDate(
                activity.start.toLocal(),
                format: 'D h:i',
              );
              if (Strings.isNotBlank(activity.notes)) {
                return '$date ${activity.notes}';
              } else {
                return date;
              }
            },
            // ignore: discarded_futures
            future: getNextJob(),

            builder:
                (_, activity) => SchedulePage(
                  defaultView: ScheduleView.week,
                  initialActivityId: activity?.id,
                  dialogMode: true,
                ),
          ),
          _buildDashlet<String>(
            context,
            label: 'Quotes',
            icon: Icons.format_quote,
            // ignore: discarded_futures
            future: getQuoteValue(),
            route: '/billing/quotes',
          ),
          _buildDashlet<String>(
            context,
            label: 'Invoices',
            icon: Icons.receipt_long,
            // ignore: discarded_futures
            future: getInvoicedThisMonth(),
            route: '/billing/invoices',
          ),
          _buildDashlet<int>(
            context,
            label: 'Ready to Invoice',
            icon: Icons.playlist_add_check,
            // ignore: discarded_futures
            future: getReadyToInvoice(),
            route: '/billing/ready_to_invoice',
          ),
          _buildDashlet<int>(
            context,
            label: 'Customers',
            icon: Icons.people,
            // ignore: discarded_futures
            future: getCustomerCount(),
            route: '/customers',
          ),
          _buildDashlet<int>(
            context,
            label: 'Suppliers',
            icon: Icons.store,
            // ignore: discarded_futures
            future: getSupplierCount(),
            route: '/suppliers',
          ),
        ],
      ),
    ),
  );

  Future<JobActivity?> getNextJob() async {
    final jobActivities = await DaoJobActivity().getActivitiesInRange(
      LocalDate.today(),
      LocalDate.today().addDays(7),
    );

    return jobActivities.isEmpty ? null : jobActivities.first;
  }

  Future<int> getPackingCount() async {
    final packingList = await DaoTaskItem().getPackingItems();
    var count = 0;
    for (final packingItem in packingList) {
      if (!packingItem.completed) {
        count++;
      }
    }
    return count;
  }

  Widget _buildDashlet<T>(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Future<T> future,
    String Function(T?)? format,
    String? route,
    DashletValueBuilder<T>? builder,
  }) {
    assert(route != null || builder != null, 'You must provided one of.');
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        if (route != null) {
          context.go(route);
        } else {
          final value = await future;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => builder!(context, value),
              fullscreenDialog: true,
            ),
          );
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: theme.primaryColor),
              const SizedBox(height: 8),
              Text(label, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              FutureBuilderEx<T>(
                future: future,
                builder:
                    (ctx, value) => Text(
                      format != null ? format(value) : value.toString(),
                      style: theme.textTheme.titleSmall!.copyWith(
                        color: Colors.white,
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<int> getReadyToInvoice() async {
    final ready = await DaoJob().readyToBeInvoiced(null);

    return ready.length;
  }

  Future<int> getCustomerCount() async {
    final count = await DaoCustomer().count();
    return count;
  }

  Future<int> getSupplierCount() async => DaoSupplier().count();

  Future<int> getActiveJobs() async {
    final activeJobs = await DaoJob().getActiveJobs(null);

    return activeJobs.length;
  }

  Future<String> getInvoicedThisMonth() async {
    final invoices = await DaoInvoice().getAll();

    var total = MoneyEx.zero;
    for (final invoice in invoices) {
      final now = DateTime.now();
      if (invoice.sent &&
          invoice.createdDate.year == now.year &&
          invoice.createdDate.month == now.month) {
        total += invoice.totalAmount;
      }
    }
    return total.format('S#');
  }

  Future<int> getShoppingCount() async {
    final shopping = await DaoTaskItem().getShoppingItems();

    var count = 0;
    for (final toBuy in shopping) {
      if (!toBuy.completed) {
        count++;
      }
    }
    return count;
  }

  Future<String> getQuoteValue() async {
    final quotes = await DaoQuote().getAll();

    var total = MoneyEx.zero;
    for (final quote in quotes) {
      if (quote.state == QuoteState.sent ||
          quote.state == QuoteState.approved) {
        total += quote.totalAmount;
      }
    }
    return total.format('S#');
  }
}
