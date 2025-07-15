/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/ui/dashboard/help_dashboard_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../main.dart';
import '../dashboard.dart';
import '../dashlet_card.dart';

class HelpDashboardPage extends StatelessWidget {
  const HelpDashboardPage({super.key});

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DashboardPage(
      title: 'Help',
      dashlets: [
        DashletCard<void>.onTap(
          label: 'Getting Started',
          hint: 'Instructions on learning how to use $appName',
          icon: Icons.info_outline,
          value: () => Future.value(const DashletValue(null)),
          onTap: (_) =>
              unawaited(_launchURL('https://hmb.onepub.dev/getting-started')),
        ),
        DashletCard<void>.onTap(
          label: 'Report an Issue',
          hint: 'Report an bug or problem with $appName',
          icon: Icons.bug_report,
          value: () => Future.value(const DashletValue(null)),
          onTap: (_) =>
              unawaited(_launchURL('https://github.com/bsutton/hmb/issues')),
        ),
        DashletCard<void>.onTap(
          label: 'Community Discussions',
          hint: 'Join community discussions to get help with $appName',
          icon: Icons.forum,
          value: () => Future.value(const DashletValue(null)),
          onTap: (_) => unawaited(
            _launchURL('https://github.com/bsutton/hmb/discussions'),
          ),
        ),
        DashletCard<void>.route(
          label: 'About',
          hint: 'Version, Author and Copyright information',
          icon: Icons.info,
          value: () => Future.value(const DashletValue(null)),
          route: '/home/help/about',
        ),
      ],
    ),
  );
}
