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

import 'dashboard.dart';
import 'dashlet_card.dart';

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
        DashletCard<void>(
          label: 'Getting Started',
          icon: Icons.info_outline,
          dashletValue: () => Future.value(const DashletValue(null)),
          onTapOverride: () =>
              unawaited(_launchURL('https://hmb.onepub.dev/getting-started')),
          widgetBuilder: (_, _) => const SizedBox.shrink(),
        ),
        DashletCard<void>(
          label: 'Report an Issue',
          icon: Icons.bug_report,
          dashletValue: () => Future.value(const DashletValue(null)),
          onTapOverride: () =>
              unawaited(_launchURL('https://github.com/bsutton/hmb/issues')),
          widgetBuilder: (_, _) => const SizedBox.shrink(),
        ),
        DashletCard<void>(
          label: 'Community Discussions',
          icon: Icons.forum,
          dashletValue: () => Future.value(const DashletValue(null)),
          onTapOverride: () => unawaited(
            _launchURL('https://github.com/bsutton/hmb/discussions'),
          ),
          widgetBuilder: (_, _) => const SizedBox.shrink(),
        ),
        DashletCard<void>(
          label: 'About',
          icon: Icons.info,
          dashletValue: () => Future.value(const DashletValue(null)),
          route: '/system/about',
          widgetBuilder: (_, _) => const SizedBox.shrink(),
        ),

        //  DashletCard<void>(
        //   label: 'Test PDF',
        //   icon: Icons.info,
        //   dashletValue: () => Future.value(const DashletValue(null)),
        //   route: '/testpdf',
        //   widgetBuilder: (_, _) => const SizedBox.shrink(),
        // ),
      ],
    ),
  );
}
