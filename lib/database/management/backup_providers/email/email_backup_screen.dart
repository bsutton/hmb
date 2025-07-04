/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../ui/widgets/hmb_button.dart';
import '../../../../ui/widgets/hmb_toast.dart';
import '../../../../util/app_title.dart';
import '../../../factory/flutter_database_factory.dart';
import '../../../versions/asset_script_source.dart';
import 'email_backup.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({required this.pathToBackup, super.key});

  final String pathToBackup;

  @override
  _BackupScreenState createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  var _includePhotos = false;

  @override
  void initState() {
    super.initState();

    setAppTitle('Backup & Restore');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      // Center the column vertically and horizontally
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Backup and Restore Your Database',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize:
                    MainAxisSize.min, // Shrink the Row to fit its children
                children: [
                  const Text('Include photos in backup'),
                  Checkbox(
                    value: _includePhotos,
                    onChanged: (value) {
                      setState(() {
                        _includePhotos = value ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            HMBButton.withIcon(
              label: 'Backup & Email Database',
              hint: 'Backup your database and email it to your self',
              onPressed: () async {
                await WakelockPlus.enable();
                try {
                  await EmailBackupProvider(
                    FlutterDatabaseFactory(),
                  ).performBackup(version: 1, src: AssetScriptSource());
                  if (context.mounted) {
                    HMBToast.info('Backup successful');
                  }
                  // ignore: avoid_catches_without_on_clauses
                } catch (e) {
                  if (context.mounted) {
                    HMBToast.error(e.toString());
                  }
                } finally {
                  await WakelockPlus.disable();
                }
              },
              icon: const Icon(Icons.backup, size: 24),
            ),
            const SizedBox(height: 20),
            HMBButton.withIcon(
              label: 'Restore Database',
              hint: 'Restore a database from Google Drive - all data since the backup occured will be lost',
              onPressed: () async {
                try {
                  await EmailBackupProvider(
                    FlutterDatabaseFactory(),
                  ).restore(context);

                  HMBToast.info('Database restored successfully.');
                  // ignore: avoid_catches_without_on_clauses
                } catch (e) {
                  HMBToast.error('Error: $e');
                }
              },
              icon: const Icon(Icons.restore, size: 24),
            ),
          ],
        ),
      ),
    ),
  );
}
