import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../ui/widgets/hmb_button.dart';
import '../../../../ui/widgets/hmb_toast.dart';
import '../../../../util/app_title.dart';
import '../../../factory/flutter_database_factory.dart';
import '../../../versions/asset_script_source.dart';
import '../backup_provider.dart';
import '../backup_selection.dart';
import '../local/local_backup_provider.dart';

class LocalBackupScreen extends StatefulWidget {
  const LocalBackupScreen({super.key});

  @override
  _LocalBackupScreenState createState() => _LocalBackupScreenState();
}

class _LocalBackupScreenState extends State<LocalBackupScreen> {
  bool _includePhotos = false;
  bool _isLoading = false; // Indicates operation in progress
  bool _useProductionPath = false; // Flag for production path in debug mode
  String _stageDescription = ''; // Description of the current stage
  int _stageNo = 0; // Current stage number
  int _stageCount = 0; // Total number of stages

  late final BackupProvider _provider;

  @override
  void initState() {
    super.initState();
    setAppTitle('Backup & Restore');
    _provider = _getProvider();
    _provider.progressStream.listen((update) {
      setState(() {
        _stageDescription = update.stageDescription;
        _stageNo = update.stageNo;
        _stageCount = update.stageCount;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  // Show progress indicator with stageNo and stageCount
                  Text(
                    'Progress: $_stageNo / $_stageCount',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
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
                  // Debug-only checkbox
                  if (kDebugMode)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Use production path for restore'),
                          Checkbox(
                            value: _useProductionPath,
                            onChanged: (value) {
                              setState(() {
                                _useProductionPath = value ?? false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  HMBButton.withIcon(
                    label: 'Backup to ${_provider.name}',
                    onPressed: () async {
                      setState(() {
                        _isLoading = true;
                        _stageDescription = 'Starting backup...';
                        _stageNo = 0;
                        _stageCount = 0;
                      });

                      await WakelockPlus.enable();
                      try {
                        await _provider.performBackup(
                          version: 1,
                          src: AssetScriptSource(),
                          includePhotos: _includePhotos,
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
                  ),
                  const SizedBox(height: 20),
                  _buildRestoreButton(context),
                ],
              ],
            ),
          ),
        ),
      );

  HMBButton _buildRestoreButton(BuildContext context) => HMBButton.withIcon(
        label: 'Restore from ${_provider.name}',
        icon: const Icon(Icons.restore, size: 24),
        onPressed: () async {
          _provider.useDebugPath = !_useProductionPath;
          final selectedBackup = await Navigator.push(
            context,
            MaterialPageRoute<Backup>(
              builder: (context) =>
                  BackupSelectionScreen(backupProvider: _provider),
            ),
          );

          if (selectedBackup != null) {
            setState(() {
              _isLoading = true;
              _stageDescription = 'Starting restore...';
              _stageNo = 0;
              _stageCount = 0;
            });

            await WakelockPlus.enable();
            try {
              await _provider.performRestore(
                selectedBackup,
                AssetScriptSource(),
                FlutterDatabaseFactory(),
              );

              if (mounted) {
                HMBToast.info('Restore completed successfully.');
              }
              // ignore: avoid_catches_without_on_clauses
            } catch (e) {
              if (mounted) {
                HMBToast.error('Error during restore: $e');
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }

              _provider.useDebugPath = false;

              await WakelockPlus.disable();
            }
          }
        },
      );

  BackupProvider _getProvider() =>
      LocalBackupProvider(FlutterDatabaseFactory());
}
