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

// lib/src/ui/about_screen.dart
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../database/management/database_helper.dart';
import '../src/version/version.g.dart';
import '../util/flutter/app_title.dart';
import 'widgets/layout/hmb_column.dart';

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
      child: HMBColumn(
        children: [
          const Text('Hold My Beer (HMB) - for solo Trades people'),
          Text('Version: $packageVersion'),
          FutureBuilderEx(
            future: DatabaseHelper().getVersion(),
            builder: (context, version) => Text('Database Version: $version'),
          ),
          const Text('Author: S. Brett Sutton'),
          const Text('Copyright © OnePub IP Pty Ltd 2025+'),
        ],
      ),
    ),
  );
}
