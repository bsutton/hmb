import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../dao/dao.g.dart';
import '../../../../ui/widgets/hmb_button.dart';
import '../../../../ui/widgets/hmb_toast.dart';
import '../../../../util/app_title.dart';
import '../../../../util/format.dart';
import '../../../factory/flutter_database_factory.dart';
import '../../../versions/asset_script_source.dart';
import '../backup.dart';
import '../backup_provider.dart';
import '../backup_selection.dart';
import '../progress_update.dart';
import 'background_backup/google_drive_backup_provider.dart';
import 'background_backup/photo_sync_params.dart';
import 'background_backup/photo_sync_service.dart';

class GoogleDriveBackupScreen extends StatefulWidget {
  const GoogleDriveBackupScreen({super.key, this.restoreOnly = false});

  @override
  _GoogleDriveBackupScreenState createState() =>
      _GoogleDriveBackupScreenState();

  final bool restoreOnly;
}

class _GoogleDriveBackupScreenState
    extends DeferredState<GoogleDriveBackupScreen> {
  var _isLoading = false;
  var _stageDescription = '';
  var _photoStageDescription = '';

  late final BackupProvider _provider;
  late Future<DateTime?> _lastBackupFuture;
  late final StreamSubscription<ProgressUpdate> _backupSub;
  late final StreamSubscription<ProgressUpdate> _photoSub;

  @override
  void initState() {
    super.initState();
    // Listen for DB backup progress (provider set in asyncInitState)
    _backupSub = _provider.progressStream.listen((update) {
      setState(() => _stageDescription = update.stageDescription);
    });
    // Listen for photo sync progress
    _photoSub = PhotoSyncService().progressStream.listen((update) {
      setState(() => _photoStageDescription = update.stageDescription);
    });
  }

  @override
  void dispose() {
    unawaited(_backupSub.cancel());
    unawaited(_photoSub.cancel());
    super.dispose();
  }

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Backup & Restore');
    _provider = _getProvider();

    // Load last backup date
    _lastBackupFuture = _refreshLastBackup();
  }

  Future<DateTime?> _refreshLastBackup() async {
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
    return last;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(automaticallyImplyLeading: false),
    body: DeferredBuilder(
      this,
      builder: (context) => Center(
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
                _buildBackupButton(),
                const SizedBox(height: 16),
                _buildLastBackup(),
                const SizedBox(height: 40),
                _buildRestoreButton(context),
                if (!widget.restoreOnly) const SizedBox(height: 40),
                if (!widget.restoreOnly) ..._buildPhotoSyncSection(),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  FutureBuilderEx<DateTime?> _buildLastBackup() => FutureBuilderEx<DateTime?>(
    future: _lastBackupFuture,
    builder: (context, lastBackupDate) {
      final text = lastBackupDate == null
          ? 'No backups yet'
          : 'Last backup: ${formatDateTime(lastBackupDate)}';
      return Text(text, style: const TextStyle(fontSize: 16));
    },
  );

  Widget _buildBackupButton() => Column(
    children: [
      HMBButton.withIcon(
        label: 'Backup to ${_provider.name}',
        icon: const Icon(Icons.backup, size: 24),
        onPressed: () async {
          await _performBackup();
          await _refreshLastBackup();
          setState(() {});
        },
      ),
    ],
  );

  Future<void> _performBackup() async {
    setState(() {
      _isLoading = true;
      _stageDescription = 'Starting backup...';
    });

    await WakelockPlus.enable();
    try {
      await _provider.performBackup(version: 1, src: AssetScriptSource());
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
      final selected = await Navigator.push<Backup>(
        context,
        MaterialPageRoute(
          builder: (c) => BackupSelectionScreen(backupProvider: _provider),
        ),
      );
      if (selected != null) {
        setState(() {
          _isLoading = true;
          _stageDescription = 'Starting restore...';
        });
        await WakelockPlus.enable();
        try {
          await _provider.performRestore(
            selected,
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

  var _syncRunning = false;

  List<Widget> _buildPhotoSyncSection() => [
    // Sync Photos Button
    HMBButton.withIcon(
      label: 'Sync Photos',
      icon: const Icon(Icons.cloud_upload, size: 24),
      onPressed: () async {
        await WakelockPlus.enable();
        try {
          _syncRunning = true;
          await _provider.syncPhotos();
        } finally {
          _syncRunning = false;
          await WakelockPlus.disable();
        }
      },
    ),
    if (_photoStageDescription.isNotEmpty) ...[
      const SizedBox(height: 8),
      Text(_photoStageDescription, style: const TextStyle(fontSize: 16)),
    ],
    if (!_syncRunning)
      FutureBuilderEx<List<PhotoPayload>>(
        // ignore: discarded_futures
        future: DaoPhoto().getUnsyncedPhotos(),
        builder: (context, unsynced) {
          final text = unsynced!.isEmpty
              ? 'All photos synced.'
              : '${unsynced.length} photos to be synced ';
          return Text(text, style: const TextStyle(fontSize: 16));
        },
      ),
  ];
}
