import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'drawer_item.dart';

class MyDrawer extends StatelessWidget {
  MyDrawer({super.key});

  final List<DrawerItem> drawerItems = [
    DrawerItem(title: 'Jobs', route: '/jobs'),
    DrawerItem(title: 'Customers', route: '/customers'),
    DrawerItem(title: 'Suppliers', route: '/suppliers'),
    DrawerItem(title: 'Shopping', route: '/shopping'),
    DrawerItem(title: 'Packing', route: '/packing'),
    DrawerItem(title: 'Billing', route: '', children: [
      DrawerItem(title: 'Quotes', route: '/billing/quotes'),
      DrawerItem(title: 'Invoices', route: '/billing/invoices'),
      DrawerItem(title: 'Estimator', route: '/billing/estimator'),
    ]),
    DrawerItem(title: 'Extras', route: '', children: [
      DrawerItem(title: 'Tools', route: '/extras/tools'),
      DrawerItem(title: 'Manufacturers', route: '/extras/manufacturers'),
    ]),
    DrawerItem(
      title: 'System',
      route: '',
      children: [
        DrawerItem(title: 'SMS Templates', route: '/system/sms_templates'),
        DrawerItem(title: 'Business', route: '/system/business'),
        DrawerItem(title: 'Billing', route: '/system/billing'),
        DrawerItem(title: 'Contact', route: '/system/contact'),
        DrawerItem(title: 'Integration', route: '/system/integration'),
        DrawerItem(title: 'Setup Wizard', route: '/system/wizard'),
        DrawerItem(title: 'About/Support', route: '/system/about'),
        DrawerItem(title: 'Backup', route: '', children: [
          DrawerItem(title: 'Google', route: '/system/backup/google'),
          DrawerItem(title: 'Local', route: '/system/backup/local'),
        ])
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: drawerItems
                .map((item) => _buildDrawerItem(item, context))
                .toList(),
          ),
        ),
      );

  Widget _buildDrawerItem(DrawerItem item, BuildContext context) {
    if (item.children != null && item.children!.isNotEmpty) {
      return ExpansionTile(
        title: Text(item.title),
        children: item.children!
            .map((child) => _buildDrawerItem(child, context))
            .toList(),
      );
    } else {
      return ListTile(
        title: Text(item.title),
        onTap: item.route.isNotEmpty
            ? () {
                Navigator.pop(context); // Close the drawer
                context.go(item.route);
              }
            : null, // Disable tap if there's no route
      );
    }
  }
}
