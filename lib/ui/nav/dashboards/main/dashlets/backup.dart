/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/ui/dashboard/shopping_dashlet.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../../../database/factory/flutter_database_factory.dart';
import '../../../../../database/management/backup_providers/google_drive/background_backup/background_backup.g.dart';
import '../../../../../database/management/backup_providers/google_drive/google_drive_auth.dart';
import '../../../../../src/appname.dart';
import '../../../../../util/format.dart';
import '../../dashlet_card.dart';

/// Dashlet for pending shopping items count
class BackupDashlet extends StatelessWidget {
  const BackupDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>.route(
    label: 'Backup',
    hint: 'Backup $appName to your Google Cloud account',
    icon: Icons.cloud,
    value: () => Future.value(const DashletValue(null)),
    route: '/home/backup',
    valueBuilder: (_, _) => _buildLastBackup(),
  );

  FutureBuilderEx<DateTime?> _buildLastBackup() => FutureBuilderEx<DateTime?>(
    // ignore: discarded_futures
    future: _getLastBackup(),
    builder: (context, lastBackupDate) {
      final text = lastBackupDate == null
          ? 'No backups yet'
          : 'Last: ${formatDateTime(lastBackupDate)}';
      return Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      );
    },
  );

  Future<DateTime?> _getLastBackup() async {
    DateTime? last;
    try {
      // google api's not supported on linux.
      if (Platform.isAndroid || Platform.isIOS) {
        if (await GoogleDriveAuth().isSignedIn) {
          final backups = await GoogleDriveBackupProvider(
            FlutterDatabaseFactory(),
          ).getBackups();
          if (backups.isNotEmpty) {
            backups.sort((a, b) => b.when.compareTo(a.when));
            last = backups.first.when;
          }
        }
      }
    } catch (_) {
      last = null;
    }
    return last;
  }
}
