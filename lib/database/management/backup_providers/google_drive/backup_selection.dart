import 'package:flutter/material.dart';

import '../../../../widgets/async_state.dart';
import '../backup_provider.dart';

class BackupSelectionScreen extends StatefulWidget {
  const BackupSelectionScreen({required this.backupProvider, super.key});

  final BackupProvider backupProvider;

  @override
  _BackupSelectionScreenState createState() => _BackupSelectionScreenState();
}

class _BackupSelectionScreenState
    extends AsyncState<BackupSelectionScreen, void> {
  late Future<List<String>> _backupsFuture;

  @override
  Future<void> asyncInitState() async {
    _backupsFuture = _loadBackups();
  }

  Future<List<String>> _loadBackups() async {
    try {
      final backups = await widget.backupProvider.getBackups();
      return backups;
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      // Handle error if necessary
      return [];
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Select Backup to Restore'),
        ),
        body: FutureBuilder<List<String>>(
          future: _backupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                  child: Text('Error loading backups: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No backups available.'));
            } else {
              final backups = snapshot.data!;
              return ListView.builder(
                itemCount: backups.length,
                itemBuilder: (context, index) {
                  final pathToBackup = backups[index];
                  return ListTile(
                    title: Text(pathToBackup),
                    onTap: () {
                      Navigator.pop(context, pathToBackup);
                    },
                  );
                },
              );
            }
          },
        ),
      );
}
