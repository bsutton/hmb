// lib/src/ui/dashboard/shopping_dashlet.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../database/factory/flutter_database_factory.dart';
import '../../../database/management/backup_providers/google_drive/api.dart';
import '../../../database/management/backup_providers/google_drive/background_backup/background_backup.g.dart';
import '../../../util/format.dart';
import '../dashlet_card.dart';

/// Dashlet for pending shopping items count
class GoogleBackupDashlset extends StatelessWidget {
  const GoogleBackupDashlset({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>(
    label: 'Backup',
    icon: Icons.cloud,
    dashletValue: () => Future.value(const DashletValue(null)),
    route: '/system/backup/google',
    widgetBuilder: (_, _) => _buildLastBackup(),
  );

  FutureBuilderEx<DateTime?> _buildLastBackup() => FutureBuilderEx<DateTime?>(
    // ignore: discarded_futures
    future: _getLastBackup(),
    builder: (context, lastBackupDate) {
      final text = lastBackupDate == null
          ? 'No backups yet'
          : 'Last: ${formatDateTime(lastBackupDate)}';
      return Text(text, style: const TextStyle(fontSize: 16));
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
