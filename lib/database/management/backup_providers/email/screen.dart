import 'package:flutter/material.dart';

import '../../../../widgets/hmb_toast.dart';
import 'backup.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({required this.pathToBackup, super.key});

  final String pathToBackup;

  @override
  // ignore: library_private_types_in_public_api
  _BackupScreenState createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Backup Database via email'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await EmailBackupProvider().performBackup(version: 1);
                    if (context.mounted) {
                      HMBToast.info( 'Backup successful');
                    }
                    // ignore: avoid_catches_without_on_clauses
                  } catch (e) {
                    if (context.mounted) {
                      HMBToast.error(e.toString());
                    }
                  }
                },
                child:
                    const Text('Backup the Database and send it as an email'),
              ),
            ],
          ),
        ),
      );
}
