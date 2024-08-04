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
    DrawerItem(
      title: 'System',
      route: '',
      children: [
        DrawerItem(title: 'Business', route: '/system/business'),
        DrawerItem(title: 'Billing', route: '/system/billing'),
        DrawerItem(title: 'Contact', route: '/system/contact'),
        DrawerItem(title: 'Integration', route: '/system/integration'),
        DrawerItem(title: 'Setup Wizard', route: '/system/wizard'),
        DrawerItem(title: 'About/Support', route: '/system/about'),
        DrawerItem(title: 'Backup', route: '/system/backup'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => Drawer(
        child: ListView.builder(
          itemCount: drawerItems.length,
          itemBuilder: (context, index) {
            final item = drawerItems[index];
            return item.children != null
                ? ExpansionTile(
                    title: Text(item.title),
                    children: item.children!
                        .map((child) => ListTile(
                              title: Text(child.title),
                              onTap: () {
                                Navigator.pop(context); // Close the drawer
                                context.go(child.route);
                              },
                            ))
                        .toList(),
                  )
                : ListTile(
                    title: Text(item.title),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer
                      context.go(item.route);
                    },
                  );
          },
        ),
      );
}
