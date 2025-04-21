import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../ui/widgets/hmb_button.dart';
import '../../../../ui/widgets/hmb_toast.dart';
import '../../../../util/app_title.dart';
import '../../../../util/format.dart';
import '../../../factory/flutter_database_factory.dart';
import '../../../versions/asset_script_source.dart';
import '../backup.dart';
import '../backup_provider.dart';
import '../backup_selection.dart';
import 'background_backup/google_drive_backup_provider.dart';

class GoogleDriveBackupScreen extends StatefulWidget {
  const GoogleDriveBackupScreen({super.key});

  @override
  _GoogleDriveBackupScreenState createState() =>
      _GoogleDriveBackupScreenState();
}

class _GoogleDriveBackupScreenState
    extends DeferredState<GoogleDriveBackupScreen> {
  bool _isLoading = false;
  String _stageDescription = '';
  bool _includePhotos = false;

  late final BackupProvider _provider;
  late Future<DateTime?> _lastBackupFuture;

  @override
  void initState() {
    super.initState();
    // Listen for progress updates
    _provider.progressStream.listen((update) {
      setState(() => _stageDescription = update.stageDescription);
    });
  }

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Backup & Restore');
    _provider = _getProvider();

    // Load last backup date
    await _refreshLastBackup();
  }

  Future<void> _refreshLastBackup() async {
    DateTime? last;

    try {
      final backups = await _provider.getBackups();
      if (backups.isNotEmpty) {
        backups.sort((a, b) => b.when.compareTo(a.when));
        last = backups.first.when;
      }
    } catch (_) {
      last = null;
    }

    // Wrap the result in a Future<DateTime?> for your FutureBuilder
    _lastBackupFuture = Future.value(last);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(automaticallyImplyLeading: false),
    body: DeferredBuilder(
      this,
      builder:
          (context) => Center(
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
                    const SizedBox(height: 16),
                    FutureBuilder<DateTime?>(
                      future: _lastBackupFuture,
                      builder: (context, snapshot) {
                        final date = snapshot.data;
                        final text =
                            date == null
                                ? 'No backups yet'
                                : 'Last backup: ${formatDateTime(date)}';
                        return Text(text, style: const TextStyle(fontSize: 16));
                      },
                    ),
                    const SizedBox(height: 40),
                    _buildBackupButton(),
                    const SizedBox(height: 40),
                    _buildRestoreButton(context),
                  ],
                ],
              ),
            ),
          ),
    ),
  );

  Widget _buildBackupButton() => Column(
    children: [
      HMBButton.withIcon(
        label: 'Backup to ${_provider.name}',
        icon: const Icon(Icons.backup, size: 24),
        onPressed: () async {
          await _performBackup(_includePhotos);
          await _refreshLastBackup();
          setState(() {});
        },
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
                setState(() => _includePhotos = value ?? false);
              },
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _performBackup(bool includePhotos) async {
    setState(() {
      _isLoading = true;
      _stageDescription = 'Starting backup...';
    });

    await WakelockPlus.enable();
    try {
      await _provider.performBackup(
        version: 1,
        src: AssetScriptSource(),
        includePhotos: includePhotos,
      );
      if (mounted) {
        HMBToast.info('Backup completed successfully.');
      }
    } catch (e) {
      if (mounted) {
        HMBToast.error('Error during backup: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      await WakelockPlus.disable();
    }
  }

  HMBButton _buildRestoreButton(BuildContext context) => HMBButton.withIcon(
    label: 'Restore from ${_provider.name}',
    icon: const Icon(Icons.restore, size: 24),
    onPressed: () async {
      _provider.useDebugPath = !false;
      final selectedBackup = await Navigator.push<Backup>(
        context,
        MaterialPageRoute(
          builder: (c) => BackupSelectionScreen(backupProvider: _provider),
        ),
      );
      if (selectedBackup != null) {
        setState(() {
          _isLoading = true;
          _stageDescription = 'Starting restore...';
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
        } catch (e) {
          if (mounted) {
            HMBToast.error('Error during restore: $e');
          }
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          _provider.useDebugPath = false;
          await WakelockPlus.disable();
        }
      }
    },
  );

  BackupProvider _getProvider() =>
      GoogleDriveBackupProvider(FlutterDatabaseFactory());
}
