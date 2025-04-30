// lib/src/ui/dashboard/help_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
    appBar: AppBar(title: const Text('Help')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          DashletCard<void>(
            label: 'Getting Started',
            icon: Icons.info_outline,
            future: Future.value(const DashletValue(null)),
            onTapOverride:
                () => _launchURL('https://hmb.onepub.dev/getting-started'),
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
          DashletCard<void>(
            label: 'Report an Issue',
            icon: Icons.bug_report,
            future: Future.value(const DashletValue(null)),
            onTapOverride:
                () => _launchURL('https://github.com/bsutton/hmb/issues'),
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
          DashletCard<void>(
            label: 'Community Discussions',
            icon: Icons.forum,
            future: Future.value(const DashletValue(null)),
            onTapOverride:
                () => _launchURL('https://github.com/bsutton/hmb/discussions'),
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
          DashletCard<void>(
            label: 'About',
            icon: Icons.info,
            future: Future.value(const DashletValue(null)),
            route: '/system/about',
            widgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}
