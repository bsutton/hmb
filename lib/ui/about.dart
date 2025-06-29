// lib/src/ui/about_screen.dart
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../database/management/database_helper.dart';
import '../src/version/version.g.dart';
import '../util/app_title.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});
  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  void initState() {
    super.initState();
    setAppTitle('About/Support');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(automaticallyImplyLeading: false),
    body: Center(
      child: Column(
        children: [
          const Text('Hold My Beer (HMB) - for solo Trades people'),
          Text('Version: $packageVersion'),
          FutureBuilderEx(
            // ignore: discarded_futures
            future: DatabaseHelper().getVersion(),
            builder: (context, version) => Text('Database Version: $version'),
          ),
          const Text('Author: S. Brett Sutton'),
        ],
      ),
    ),
  );
}
