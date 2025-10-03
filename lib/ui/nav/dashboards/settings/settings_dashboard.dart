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

// lib/src/ui/dashboard/settings_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/layout/layout.g.dart';
import '../dashboard.dart';
import '../dashlet_card.dart';

class SettingsDashboardPage extends StatelessWidget {
  const SettingsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => DashboardPage(
    title: 'Settings',
    dashlets: [
      DashletCard<void>.route(
        label: 'SMS Templates',
        hint: 'Maintain SMS Templates to speed up sending text messages',
        icon: Icons.message,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/settings/sms_templates',
        valueBuilder: (_, _) =>  const HMBEmpty(),
      ),
      DashletCard<void>.route(
        label: 'Business',
        hint:
            'Maintain your Business Name/No. Unit System, Web links and Operating Hours',
        icon: Icons.business,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/settings/business',
        valueBuilder: (_, _) =>  const HMBEmpty(),
      ),
      DashletCard<void>.route(
        label: 'Billing',
        hint:
            '''Maintain rates, bank details, payment options and formatting for Invoices and Quotes''',
        icon: Icons.account_balance,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/settings/billing',
        valueBuilder: (_, _) =>  const HMBEmpty(),
      ),
      DashletCard<void>.route(
        label: 'Contact',
        hint:
            '''Maintain your buinsess Contact Details used on Quotes and Invoices''',
        icon: Icons.contact_phone,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/settings/contact',
        valueBuilder: (_, _) =>  const HMBEmpty(),
      ),
      DashletCard<void>.route(
        label: 'Integrations',
        hint:
            '''Configure integrations to third party systems like Accounting Packages''',
        icon: Icons.extension,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/settings/integrations',
        valueBuilder: (_, _) =>  const HMBEmpty(),
      ),
      DashletCard<void>.onTap(
        label: 'Setup Wizard',
        hint: 'Run the setup wizard',
        icon: Icons.auto_fix_high,
        value: () => Future.value(const DashletValue(null)),
        onTap: (_) => context.push('/home/settings/wizard', extra: true),
        valueBuilder: (_, _) =>  const HMBEmpty(),
      ),
    ],
  );
}
