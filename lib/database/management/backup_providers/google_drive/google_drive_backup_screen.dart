import 'dart:async';
import 'dart:io';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../dao/dao.g.dart';
import '../../../../ui/widgets/color_ex.dart';
import '../../../../ui/widgets/hmb_button.dart';
import '../../../../ui/widgets/hmb_toast.dart';
import '../../../../util/app_title.dart';
import '../../../../util/format.dart';
import '../../../../util/hmb_theme.dart';
import '../../../factory/flutter_database_factory.dart';
import '../../../versions/asset_script_source.dart';
import '../backup.dart';
import '../backup_provider.dart';
import '../backup_selection.dart';
import '../progress_update.dart';
import 'api.dart';
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

  var _isGoogleSignedIn = false;

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Backup & Restore');
    _provider = _getProvider();

    if (await GoogleDriveAuth().isSignedIn) {
      // Load last backup date
      _lastBackupFuture = _refreshLastBackup();
      _isGoogleSignedIn = true;
    }
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
      builder: (context) {
        if (Platform.isLinux || Platform.isWindows) {
          return _buildUnsupportedPlatformMessage(context);
        }

        if (_isGoogleSignedIn) {
          return _buildBackupUI(context);
        } else {
          return _buildSignInPrompt(context);
        }
      },
    ),
  );
  Widget _buildBackupUI(BuildContext context) => Center(
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
            const SizedBox(height: 40),
            HMBButton.withIcon(
              label: 'Sign Out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final googleSignIn = GoogleSignIn();
                await googleSignIn.signOut();
                setState(() {
                  _isGoogleSignedIn = false;
                });
              },
            ),
          ],
        ],
      ),
    ),
  );

  FutureBuilderEx<DateTime?> _buildLastBackup() => FutureBuilderEx<DateTime?>(
    future: _lastBackupFuture,
    builder: (context, lastBackupDate) {
      final text = lastBackupDate == null
          ? 'No backups yet'
          : 'Last: ${formatDateTime(lastBackupDate)}';
      return Center(child: Text(text, style: const TextStyle(fontSize: 16)));
    },
  );

  Widget _buildBackupButton() => Column(
    children: [
      HMBButton.withIcon(
        label: 'Backup to ${_provider.name}',
        icon: const Icon(Icons.backup, size: 24),
        onPressed: () async {
          await _performBackup();
          _lastBackupFuture = _refreshLastBackup();
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

  Widget _buildSignInPrompt(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withSafeOpacity(0.8),
            HMBColors.accent.withSafeOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🔐 Google Drive Backup',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'To enable cloud backups, please sign in to your Google account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 32),
            HMBButton.withIcon(
              icon: const Icon(Icons.login, color: Colors.white),
              label: 'Sign in to Google',
              onPressed: () async {
                GoogleDriveAuth? auth;
                try {
                  auth = await GoogleDriveAuth.init();
                  if (await auth.isSignedIn && mounted) {
                    _lastBackupFuture = _refreshLastBackup();
                    _isGoogleSignedIn = true;
                    setState(() {});
                  }
                } catch (e) {
                  /// ensure we are not left in a 'half signed-in'
                  /// state.
                  await auth?.signOut();
                  if (mounted) {
                    HMBToast.error('Sign-in failed: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupportedPlatformMessage(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withSafeOpacity(0.8),
            HMBColors.accent.withSafeOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🚫 Not Supported',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Google Drive backup is not supported on Linux or Windows.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
