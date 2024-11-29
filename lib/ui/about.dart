import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this import to handle URL launching

import '../database/management/database_helper.dart';
import '../src/version/version.g.dart';
import '../util/exceptions.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('About/Support'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Hold My Beer (HMB) - I'm a handyman"),
              Text('Version: $packageVersion'),
              FutureBuilderEx(
                  // ignore: discarded_futures
                  future: DatabaseHelper().getVersion(),
                  builder: (context, version) =>
                      Text('Database Version: $version')),
              const Text('Author: S. Brett Sutton'),
              const SizedBox(height: 20),
              const Text(
                'Get Support',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...linkButton(
                  description: 'Read the manual and getting started guide',
                  label: 'Manual/Getting Started',
                  link: 'https://hmb.onepub.dev'),
              ...linkButton(
                  description: 'Have a problem; raise issues',
                  label: 'GitHub Repository',
                  link: 'https://github.com/bsutton/hmb'),
              ...linkButton(
                  description: 'Feel free to start a discussion:',
                  label: 'Discussions',
                  link: 'https://github.com/bsutton/hmb/discussions'),
            ],
          ),
        ),
      );

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw HMBException('Could not launch $url');
    }
  }

  List<Widget> linkButton(
          {required String description,
          required String label,
          required String link}) =>
      [
        Text(
          description,
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: () async => _launchURL(link),
          child: Text(
            label,
            style: const TextStyle(color: Colors.blue),
          ),
        )
      ];
}
