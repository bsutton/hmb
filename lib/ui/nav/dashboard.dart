// lib/src/ui/dashboard/dashboard_page.dart

// ignore_for_file: discarded_futures

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
import 'route.dart';

/// Holds primary and optional secondary values for a dashlet
class DashletValue<T> {
  DashletValue(this.value, [this.secondValue]);
  final T value;
  final String? secondValue;
}

typedef DashletWidgetBuilder<T> =
    Widget Function(BuildContext context, DashletValue<T> dv);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with RouteAware {
  @override
  void initState() {
    super.initState();
    setAppTitle('Dashboard');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // subscribe this State to route events
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // Called when a pushed route is popped back to this one.
    // Re‐build so all the values for dashlets are recalculated
    setState(() {});
    // Reset title, too, if needed
    setAppTitle('Dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
              future: getActiveJobs(),
              route: '/jobs',
            ),
            _buildDashlet<int>(
              context,
              label: 'Shopping',
              icon: Icons.shopping_cart,
              future: getShoppingCount(),
              route: '/shopping',
            ),
            _buildDashlet<int>(
              context,
              label: 'Packing',
              icon: Icons.inventory_2,
              future: getPackingCount(),
              route: '/packing',
            ),
            _buildDashlet<JobActivity?>(
              context,
              label: 'Next Job',
              icon: Icons.schedule,
              future: getNextJob(),
              widgetBuilder: (ctx, dv) {
                final theme = Theme.of(context);
                if (dv.value == null) {
                  return Text('—', style: theme.textTheme.titleSmall);
                }
                final date = formatDate(
                  dv.value!.start.toLocal(),
                  format: 'D h:i',
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(date, style: theme.textTheme.titleSmall),
                    if (Strings.isNotBlank(dv.secondValue))
                      Text(
                        dv.secondValue!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                );
              },
              builder:
                  (_, dv) => SchedulePage(
                    defaultView: ScheduleView.week,
                    initialActivityId: dv.value?.id,
                    dialogMode: true,
                  ),
            ),
            _buildDashlet<String>(
              context,
              label: 'Quotes',
              icon: Icons.format_quote,
              future: getQuoteValue(),
              route: '/billing/quotes',
            ),
            _buildDashlet<String>(
              context,
              label: 'Invoices',
              icon: Icons.receipt_long,
              future: getInvoicedThisMonth(),
              route: '/billing/invoices',
            ),
            _buildDashlet<int>(
              context,
              label: 'To be Invoiced',
              icon: Icons.attach_money,
              future: getYetToBeInvoiced(),
              route: '/billing/to_be_invoiced',
            ),
            _buildDashlet<int>(
              context,
              label: 'Customers',
              icon: Icons.people,
              future: getCustomerCount(),
              route: '/customers',
            ),
            _buildDashlet<int>(
              context,
              label: 'Suppliers',
              icon: Icons.store,
              future: getSupplierCount(),
              route: '/suppliers',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashlet<T>(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Future<DashletValue<T>> future,
    String? route,
    DashletWidgetBuilder<T>? widgetBuilder,
    DashletWidgetBuilder<T>? builder,
  }) {
    assert(
      route != null || builder != null || widgetBuilder != null,
      'Provide route or builder',
    );
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final iconColor = theme.colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        if (route != null) {
          // 1) push the named route
          await context.push(route);
          // 2) once we pop back, reset title
          setAppTitle('Dashboard');
        } else {
          final dv = await future;
          if (!context.mounted) {
            return;
          }
          // push the widget‐builder route
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (c) => (builder ?? widgetBuilder)!(c, dv),
              fullscreenDialog: true,
            ),
          );
          setAppTitle('Dashboard');
        }
      },
      child: Card(
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilderEx<DashletValue<T>>(
              future: future,
              builder: (ctx, dv) {
                if (dv == null) {
                  return const SizedBox();
                }
                return widgetBuilder != null
                    ? widgetBuilder(ctx, dv)
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dv.value.toString(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (dv.secondValue != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            dv.secondValue!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<DashletValue<JobActivity?>> getNextJob() async {
    final acts = await DaoJobActivity().getActivitiesInRange(
      LocalDate.today(),
      LocalDate.today().addDays(7),
    );
    final act = acts.isEmpty ? null : acts.first;
    return DashletValue(act, act?.notes);
  }

  Future<DashletValue<int>> getPackingCount() async {
    final packing = await DaoTaskItem().getPackingItems();
    var count = 0;
    for (final item in packing) {
      if (!item.completed) {
        count++;
      }
    }
    return DashletValue(count);
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

  Future<DashletValue<int>> getCustomerCount() async {
    final count = await DaoCustomer().count();
    return DashletValue(count);
  }

  Future<DashletValue<int>> getSupplierCount() async {
    final count = await DaoSupplier().count();
    return DashletValue(count);
  }

  Future<DashletValue<int>> getActiveJobs() async {
    final active = await DaoJob().getActiveJobs(null);
    var count = 0;
    for (final job in active) {
      count++;
    }
    return DashletValue(count);
  }

  Future<DashletValue<String>> getInvoicedThisMonth() async {
    final invoices = await DaoInvoice().getAll();
    final now = DateTime.now();
    var total = MoneyEx.zero;
    for (final inv in invoices) {
      if (inv.sent &&
          inv.createdDate.year == now.year &&
          inv.createdDate.month == now.month) {
        total += inv.totalAmount;
      }
    }
    return DashletValue(total.format('S#'));
  }

  Future<DashletValue<int>> getShoppingCount() async {
    final shopping = await DaoTaskItem().getShoppingItems();
    var count = 0;
    for (final item in shopping) {
      if (!item.completed) {
        count++;
      }
    }
    return DashletValue(count);
  }

  Future<DashletValue<String>> getQuoteValue() async {
    final quotes = await DaoQuote().getAll();
    var total = MoneyEx.zero;
    for (final q in quotes) {
      if (q.state == QuoteState.sent || q.state == QuoteState.approved) {
        total += q.totalAmount;
      }
    }
    return DashletValue(total.format('S#'));
  }
}
