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
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../../../database/factory/flutter_database_factory.dart';
import '../../../../../database/management/backup_providers/google_drive/background_backup/background_backup.g.dart';
import '../../../../../database/management/backup_providers/google_drive/google_drive.g.dart';
import '../../../../../src/appname.dart';
import '../../../../../util/dart/format.dart';
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

  Widget _buildLastBackup() => FutureBuilderEx<BackupStatus>(
    // ignore: discarded_futures
    future: _getLastBackup(),
    builder: (context, backupStatus) {
      final text = switch (backupStatus!.driveStatus) {
        GoogleDriveStatus.signedIn =>
          backupStatus.lastBackup == null
              ? 'No backups yet'
              : 'Last: ${formatDateTime(backupStatus.lastBackup!)}',
        GoogleDriveStatus.signedOut => 'Not Signed In',
        GoogleDriveStatus.notSupported => 'Not Supported',
      };
      return Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      );
    },
  );

  Future<BackupStatus> _getLastBackup() async {
    DateTime? last;
    var status = GoogleDriveStatus.notSupported;
    try {
      if (GoogleDriveApi.isSupported()) {
        status = GoogleDriveStatus.signedOut;
        final auth = await GoogleDriveAuth.instance();
        if (auth.isSignedIn) {
          status = GoogleDriveStatus.signedIn;
          final backups = await GoogleDriveBackupProvider(
            FlutterDatabaseFactory(),
          ).getBackups();
          if (backups.isNotEmpty) {
            backups.sort((a, b) => b.when.compareTo(a.when));
            last = backups.first.when;
          }
        }
      }
    } catch (_) {}
    return BackupStatus(driveStatus: status, lastBackup: last);
  }
}

class BackupStatus {
  final GoogleDriveStatus driveStatus;
  final DateTime? lastBackup;

  BackupStatus({required this.driveStatus, required this.lastBackup});
}
