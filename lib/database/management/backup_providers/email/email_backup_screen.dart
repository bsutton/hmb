import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../ui/widgets/hmb_toast.dart';
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
  bool _includePhotos = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Backup & Restore'),
          centerTitle: true,
          backgroundColor: Colors.blue,
        ),
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
                ElevatedButton.icon(
                  onPressed: () async {
                    await WakelockPlus.enable();
                    try {
                      await EmailBackupProvider(FlutterDatabaseFactory())
                          .performBackup(
                              version: 1,
                              src: AssetScriptSource(),
                              includePhotos: _includePhotos);
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
                  label: const Text('Backup & Email Database'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // Button color
                    foregroundColor: Colors.white, // Text color
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await EmailBackupProvider(FlutterDatabaseFactory())
                          .restore(context);

                      HMBToast.info('Database restored successfully.');
                      // ignore: avoid_catches_without_on_clauses
                    } catch (e) {
                      HMBToast.error('Error: $e');
                    }
                  },
                  icon: const Icon(Icons.restore, size: 24),
                  label: const Text('Restore Database'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
