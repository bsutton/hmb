import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../ui/widgets/hmb_toast.dart';
import '../../../factory/flutter_database_factory.dart';
import '../../../versions/asset_script_source.dart';
import '../backup_provider.dart';
import '../local/local_backup_provider.dart';
import 'google_drive_backup_provider.dart';

class GoogleDriveBackupScreen extends StatefulWidget {
  const GoogleDriveBackupScreen({super.key});

  @override
  _GoogleDriveBackupScreenState createState() =>
      _GoogleDriveBackupScreenState();
}

class _GoogleDriveBackupScreenState extends State<GoogleDriveBackupScreen> {
  bool _isLoading = false; // Indicates operation in progress
  String _stageDescription = ''; // Current stage of the operation

  late final BackupProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = _getProvider();
    _provider.progressStream.listen((update) {
      setState(() {
        _stageDescription = update.stageDescription;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Backup & Restore'),
          centerTitle: true,
          backgroundColor: Colors.blue,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _stageDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                ] else ...[
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
                  ElevatedButton.icon(
                    onPressed: () async {
                      setState(() {
                        _isLoading = true;
                        _stageDescription = 'Starting backup...';
                      });

                      await WakelockPlus.enable();
                      try {
                        await _provider.performBackup(
                          version: 1,
                          src: AssetScriptSource(),
                          includePhotos: true,
                        );
                        if (mounted) {
                          HMBToast.info('Backup completed successfully.');
                        }
                        // ignore: avoid_catches_without_on_clauses
                      } catch (e) {
                        if (mounted) {
                          HMBToast.error('Error during backup: $e');
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                        }
                        await WakelockPlus.disable();
                      }
                    },
                    icon: const Icon(Icons.backup, size: 24),
                    label: Text('Backup to ${_provider.name}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
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
              ],
            ),
          ),
        ),
      );

  BackupProvider _getProvider() {
    if (Platform.isAndroid) {
      return GoogleDriveBackupProvider(FlutterDatabaseFactory());
    }
    return LocalBackupProvider(FlutterDatabaseFactory());
  }
}
