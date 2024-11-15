import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../widgets/hmb_toast.dart';
import '../../../factory/flutter_database_factory.dart';
import '../../../versions/asset_script_source.dart';
import '../backup_provider.dart';
import '../local/local_backup_provider.dart';
import 'backup_selection.dart';
import 'google_drive_backup_provider.dart';

class GoogleDriveBackupScreen extends StatefulWidget {
  const GoogleDriveBackupScreen({super.key});

  @override
  _GoogleDriveBackupScreenState createState() =>
      _GoogleDriveBackupScreenState();
}

class _GoogleDriveBackupScreenState extends State<GoogleDriveBackupScreen> {
  bool _includePhotos = false;
  bool _isLoading = false; // To show a loading indicator during operations

  late final BackupProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = _getProvider();
  }

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
            child: _isLoading
                ? const CircularProgressIndicator() // Show loading indicator
                : Column(
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
                          mainAxisSize: MainAxisSize.min,
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
                          setState(() {
                            _isLoading = true;
                          });
                          try {
                            await _provider.performBackup(
                              version: 1,
                              src: AssetScriptSource(),
                              includePhotos: _includePhotos,
                            );
                            if (context.mounted) {
                              HMBToast.info('''
Backup uploaded to Google Drive successfully.''');
                            }
                            // ignore: avoid_catches_without_on_clauses
                          } catch (e) {
                            if (context.mounted) {
                              HMBToast.error('Error during backup: $e');
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                        icon: const Icon(Icons.backup, size: 24),
                        label: Text('Backup to ${_provider.name}'),
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
                          // Navigate to the backup selection screen
                          final selectedBackup = await Navigator.push(
                            context,
                            MaterialPageRoute<String>(
                              builder: (context) => BackupSelectionScreen(
                                  backupProvider: _provider),
                            ),
                          );

                          if (selectedBackup != null) {
                            setState(() {
                              _isLoading = true;
                            });
                            try {
                              await _provider.performRestore(
                                  selectedBackup,
                                  AssetScriptSource(),
                                  FlutterDatabaseFactory());
                              if (context.mounted) {
                                HMBToast.info('''
Database restored from Google Drive successfully.''');
                              }
                              // ignore: avoid_catches_without_on_clauses
                            } catch (e) {
                              if (context.mounted) {
                                HMBToast.error('Error during restore: $e');
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.restore, size: 24),
                        label: Text('Restore from ${_provider.name}'),
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

  BackupProvider _getProvider() {
    if (Platform.isAndroid) {
      return GoogleDriveBackupProvider(FlutterDatabaseFactory());
    }
    return LocalBackupProvider(FlutterDatabaseFactory());
  }
}
