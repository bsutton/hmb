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

import 'package:flutter/material.dart';

import '../dashboard.dart';
import '../dashlet_card.dart';

class IntegrationDashboardPage extends StatelessWidget {
  const IntegrationDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => DashboardPage(
    title: 'Integrations',
    dashlets: [
      DashletCard<void>.route(
        label: 'ihserver',
        hint: 'Import website booking requests into HMB',
        icon: Icons.cloud_download,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/settings/integrations/ihserver',
      ),
      DashletCard<void>.route(
        label: 'ChatGPT',
        hint: 'Enable AI summaries and task extraction',
        icon: Icons.smart_toy,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/settings/integrations/chatgpt',
      ),
      DashletCard<void>.route(
        label: 'Google Maps',
        hint: 'Enable mailing geocoding and route optimisation',
        icon: Icons.map,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/settings/integrations/google_maps',
      ),
      DashletCard<void>.route(
        label: 'Xero',
        hint: 'Configure integration with Xero to upload Invoices',
        icon: Icons.extension,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/settings/integrations/xero',
      ),
      DashletCard<void>.route(
        label: 'SMTP Email',
        hint: 'Configure email delivery with attachments',
        icon: Icons.email,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/settings/integrations/smtp',
      ),
    ],
  );
}
