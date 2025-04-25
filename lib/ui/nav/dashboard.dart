// lib/src/ui/dashboard/dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_invoice.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_job_activity.dart';
import '../../dao/dao_quote.dart';
import '../../dao/dao_supplier.dart';
import '../../dao/dao_task_item.dart';
import '../../entity/quote.dart';
import '../../util/app_title.dart';
import '../../util/format.dart';
import '../../util/local_date.dart';
import '../../util/money_ex.dart';

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
          _buildDashlet<String>(
            context,
            label: 'Next Job',
            icon: Icons.schedule,
            // ignore: discarded_futures
            future: getNextJob(),
            route: '/schedule',
          ),
          _buildDashlet<Money>(
            context,
            label: 'Quotes',
            icon: Icons.format_quote,
            // ignore: discarded_futures
            future: getQuoteValue(),
            route: '/billing/quotes',
          ),
          _buildDashlet<Money>(
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
            route: '/billing/invoices',
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

  Future<String> getNextJob() async {
    final jobActivities = await DaoJobActivity().getActivitiesInRange(
      LocalDate.today(),
      LocalDate.today().addDays(7),
    );
    if (jobActivities.isEmpty) {
      return '—';
    }

    final activity = jobActivities.first;
    final date = formatDate(activity.start.toLocal(), format: 'D h:i');
    if (Strings.isNotBlank(activity.notes)) {
      return '$date ${activity.notes}';
    } else {
      return date;
    }
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
    required String route,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go(route),
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
                      '$value',
                      style: theme.textTheme.titleLarge!.copyWith(
                        color: theme.primaryColorDark,
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
    final activeJobs = await DaoJob().getActiveJobs(null);

    var count = 0;
    for (final job in activeJobs) {
      if (await DaoJob().hasBillableTasks(job)) {
        count++;
      }
    }
    return count;
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

  Future<Money> getInvoicedThisMonth() async {
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
    return total;
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

  Future<Money> getQuoteValue() async {
    final quotes = await DaoQuote().getAll();

    var total = MoneyEx.zero;
    for (final quote in quotes) {
      if (quote.state == QuoteState.sent ||
          quote.state == QuoteState.approved) {
        total += quote.totalAmount;
      }
    }
    return total;
  }
}
