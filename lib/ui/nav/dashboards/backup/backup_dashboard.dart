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

// lib/src/ui/dashboard/help_dashboard_page.dart
import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../dao/dao.g.dart';
import '../../../../database/factory/factory.g.dart';
import '../../../../database/management/backup_providers/backup_providers.g.dart';
import '../../../../database/management/backup_providers/google_drive/background_backup/background_backup.g.dart'
    hide ProgressUpdate;
import '../../../../database/management/backup_providers/google_drive/google_drive.g.dart';
import '../../../../database/versions/source.dart';
import '../../../../src/appname.dart';
import '../../../../util/flutter/flutter_util.g.dart';
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/widgets.g.dart';
import '../dashboard.dart';
import '../dashlet_card.dart';

class BackupDashboardPage extends StatefulWidget {
  const BackupDashboardPage({super.key});

  @override
  State<BackupDashboardPage> createState() => _BackupDashboardPageState();
}

class _BackupDashboardPageState extends DeferredState<BackupDashboardPage> {
  var _isDbOffline = false;
  var _photoStageDescription = '';
  var _syncRunning = false;

  late final GoogleDriveAuth auth;

  late final BackupProvider _provider;
  DateTime? _lastBackup;
  late final StreamSubscription<ProgressUpdate> _photoSub;

  @override
  void initState() {
    super.initState();
    // Listen for photo sync progress
    _photoSub = PhotoSyncService().progressStream.listen((update) {
      setState(() => _photoStageDescription = update.stageDescription);
    });
  }

  var authIsSupported = false;
  @override
  Future<void> asyncInitState() async {
    _provider = _getProvider();
    authIsSupported = GoogleDriveAuth.isAuthSupported();

    if (authIsSupported) {
      auth = await GoogleDriveAuth.instance();
      // Do not auto-sign-in when opening dashboard.
      // Sign-in is now only requested when user taps backup/restore/sync.
      _lastBackup = null;
    }
  }

  @override
  void dispose() {
    unawaited(_photoSub.cancel());
    super.dispose();
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
    body: DeferredBuilder(
      this,
      builder: (context) {
        if (!authIsSupported) {
          return _buildUnsupportedPlatformMessage(context);
        }
        if (auth.isSignedIn) {
          return _buildDashboard();
        } else {
          return _buildSignInPrompt(context);
        }
      },
    ),
  );

  DashboardPage _buildDashboard() => DashboardPage(
    title: 'Backup',
    dashlets: [
      DashletCard<void>.onTap(
        label: 'Backup',
        hint:
            '''Backup your $appName data to your Google Drive Account (recommended)''',
        icon: Icons.info_outline,
        onTap: (_) =>
            BlockingUI().run(_performBackup, label: 'Performing Backup'),
        value: () async => const DashletValue(null),
        valueBuilder: (_, _) {
          final text = !auth.isSignedIn
              ? 'Not Signed In'
              : _lastBackup == null
              ? 'No backups yet'
              : 'Last: ${formatDateTime(_lastBackup!)}';
          return Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          );
        },
      ),

      DashletCard<void>.onTap(
        label: 'Restore',
        hint: 'Restore $appName data from your Google Drive Account',
        icon: Icons.bug_report,
        value: () => Future.value(const DashletValue(null)),
        onTap: _performRestore,
      ),

      DashletCard<void>.route(
        label: 'Backup Local',
        hint:
            '''Make a local backup of $appName database - using Google Drive is safer.''',
        icon: Icons.save,
        value: () => Future.value(const DashletValue(null)),
        route: '/home/backup/local/backup',
        valueBuilder: (_, _) => const HMBEmpty(),
      ),

      DashletCard<void>.onTap(
        label: 'Sync Photos',
        hint: 'Copy your photos to google drive - including receipts and tools',
        icon: Icons.forum,
        value: () async => const DashletValue(null),
        valueBuilder: (_, _) => _syncPhotoBuilder(),
        onTap: (_) => _syncPhotos(),
      ),

      DashletCard<void>.onTap(
        label: 'Signout',
        hint: 'Sign out of your Google Drive Account',
        icon: Icons.info,
        value: () => Future.value(const DashletValue(null)),
        onTap: (_) => signout(),
      ),
    ],
  );

  // FutureBuilderEx<DateTime?> _buildLastBackup() =>
  // FutureBuilderEx<DateTime?>(
  //   future: _lastBackupFuture,
  //   builder: (context, lastBackupDate) {
  //     final text = lastBackupDate == null
  //         ? 'No backups yet'
  //         : 'Last: ${formatDateTime(lastBackupDate)}';
  //     return Center(child: Text(text, style: const TextStyle(fontSize: 16)));
  //   },
  // );

  Future<void> _performBackup() async {
    if (!await _ensureSignedInForAction()) {
      return;
    }
    setState(() {
      _isDbOffline = true;
    });

    await WakelockPlus.enable();
    try {
      await _provider.performBackup(version: 1, src: AssetScriptSource());
      final refreshedLastBackup = await _refreshLastBackup();
      if (mounted) {
        setState(() => _lastBackup = refreshedLastBackup);
        HMBToast.info('Backup completed successfully.');
      }
    } catch (e) {
      if (mounted) {
        HMBToast.error('Error during backup: $e');
      }
    } finally {
      _isDbOffline = false;
      if (mounted) {
        setState(() {});
      }
      await WakelockPlus.disable();
    }
  }

  BackupProvider _getProvider() =>
      GoogleDriveBackupProvider(FlutterDatabaseFactory());

  Future<void> _performRestore(BuildContext context) async {
    if (!await _ensureSignedInForAction()) {
      return;
    }
    _provider.useDebugPath = !false;
    final selected = await Navigator.push<Backup>(
      context,
      MaterialPageRoute(
        builder: (c) => BackupSelectionScreen(backupProvider: _provider),
      ),
    );
    if (selected != null) {
      setState(() {
        _isDbOffline = true;
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
          setState(() => _isDbOffline = false);
        }
        _provider.useDebugPath = false;
        await WakelockPlus.disable();
      }
    }
  }

  Future<void> _syncPhotos() async {
    if (!await _ensureSignedInForAction()) {
      return;
    }
    // Sync Photos Button
    await WakelockPlus.enable();
    try {
      _syncRunning = true;
      await _provider.syncPhotos();
    } finally {
      _syncRunning = false;
      await WakelockPlus.disable();
    }
  }

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
        child: HMBColumn(
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '''To enable cloud backups, please sign in to your Google account.''',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            ),
            HMBButton.withIcon(
              icon: const Icon(Icons.login, color: Colors.white),
              label: 'Sign in to Google',
              hint:
                  '''Sign into Google Drive so you can back up your data and Sync your photos''',
              onPressed: () async {
                GoogleDriveAuth? auth;
                try {
                  auth = await GoogleDriveAuth.instance();
                  await auth.signIn();
                  if (auth.isSignedIn && mounted) {
                    /// kick off a refresh but we need to rebuild the ui
                    /// now to remove the 'google login' screen.
                    setState(() {});
                    Future.delayed(Duration.zero, () async {
                      _lastBackup = await _refreshLastBackup();
                      if (mounted) {
                        setState(() {});
                      }
                    });
                  }
                } on GoogleAuthResult catch (e) {
                  await auth?.signOut();
                  if (mounted) {
                    if (!e.wasCancelled) {
                      HMBToast.error('Sign-in failed: $e');
                    }
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
          child: HMBColumn(
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

  Future<void> signout() async {
    GoogleDriveAuth? auth;
    auth = await GoogleDriveAuth.instance();
    await auth.signOut();
    setState(() {});
  }

  Future<bool> _ensureSignedInForAction() async {
    if (auth.isSignedIn) {
      return true;
    }
    try {
      await auth.signIn();
      if (!auth.isSignedIn) {
        return false;
      }
      _lastBackup = await _refreshLastBackup();
      if (mounted) {
        setState(() {});
      }
      return true;
    } on GoogleAuthResult catch (e) {
      if (mounted && !e.wasCancelled) {
        HMBToast.error('Sign-in failed: $e');
      }
      return false;
    } catch (e) {
      if (mounted) {
        HMBToast.error('Sign-in failed: $e');
      }
      return false;
    }
  }

  Widget _syncPhotoBuilder() => HMBColumn(
    children: [
      if (_photoStageDescription.isNotEmpty) ...[
        Text(_photoStageDescription, style: const TextStyle(fontSize: 16)),
      ],
      if (!_isDbOffline && !_syncRunning)
        FutureBuilderEx<List<PhotoPayload>>(
          future: DaoPhoto().getUnsyncedPhotos(),
          builder: (context, unsynced) {
            final text = unsynced!.isEmpty
                ? 'All photos synced.'
                : '${unsynced.length} photos to be synced ';
            return Text(text, style: const TextStyle(fontSize: 16));
          },
        ),
    ],
  );
}
