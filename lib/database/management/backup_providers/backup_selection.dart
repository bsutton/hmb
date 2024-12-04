import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../ui/widgets/async_state.dart';
import '../../../ui/widgets/text/hmb_text.dart';
import '../../../util/format.dart';
import 'backup_provider.dart';

class BackupSelectionScreen extends StatefulWidget {
  const BackupSelectionScreen({required this.backupProvider, super.key});

  final BackupProvider backupProvider;

  @override
  _BackupSelectionScreenState createState() => _BackupSelectionScreenState();
}

class _BackupSelectionScreenState
    extends AsyncState<BackupSelectionScreen, void> {
  late Future<Backups> _backupsFuture;

  @override
  Future<void> asyncInitState() async {
    _backupsFuture = _loadBackups();
  }

  Future<Backups> _loadBackups() async {
    try {
      final backups = await widget.backupProvider.getBackups();
      backups.sort((a, b) => b.when.compareTo(a.when));
      return Backups(backups, await widget.backupProvider.backupLocation);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      // Handle error if necessary
      return Backups([], await widget.backupProvider.backupLocation);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Select Backup to Restore'),
        ),
        body: FutureBuilderEx<Backups>(
          future: _backupsFuture,
          errorBuilder: (context, error) =>
              Center(child: Text('Error loading backups: $error')),
          builder: (context, backups) {
            if (backups == null || backups.backups.isEmpty) {
              return Center(child: Text('''
No backups available in ${backups!.location}'''));
            } else {
              return Column(
                children: [
                  HMBText('Location: ${backups.location}'),
                  Expanded(
                    child: ListView.builder(
                      itemCount: backups.backups.length,
                      itemBuilder: (context, index) {
                        final backup = backups.backups[index];
                        return ListTile(
                          title: Text(
                              ' ${formatDateTime(backup.when)} ${backup.size}'),
                          onTap: () {
                            Navigator.pop(context, backup);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            }
          },
        ),
      );
}

class Backups {
  Backups(this.backups, this.location);
  List<Backup> backups;
  String location;
}
