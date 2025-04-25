// lib/src/ui/dashboard/dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const _items = [
    _DashboardItem('Jobs', Icons.work, '/jobs'),
    _DashboardItem('Customers', Icons.people, '/customers'),
    _DashboardItem('Suppliers', Icons.store, '/suppliers'),
    _DashboardItem('Shopping', Icons.shopping_cart, '/shopping'),
    _DashboardItem('Packing', Icons.inventory_2, '/packing'),
    _DashboardItem('Schedule', Icons.schedule, '/schedule'),
    _DashboardItem(
      'Ready to Invoice',
      Icons.playlist_add_check,
      '/billing/invoices',
    ),
    _DashboardItem('Quotes', Icons.format_quote, '/billing/quotes'),
    _DashboardItem('Invoices', Icons.receipt_long, '/billing/invoices'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: _items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemBuilder: (context, idx) {
            final item = _items[idx];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go(item.route),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 48, color: theme.primaryColor),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardItem {
  const _DashboardItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}
