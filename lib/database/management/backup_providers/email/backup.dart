import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:strings/strings.dart';

import '../../../../dao/dao_system.dart';
import '../../../../util/exceptions.dart';
import '../../../../widgets/hmb_file_picker_linux.dart';
import '../../../../widgets/hmb_toast.dart';
import '../../../factory/hmb_database_factory.dart';
import '../../../versions/asset_script_source.dart';
import '../backup_provider.dart';

class EmailBackupProvider extends BackupProvider {
  EmailBackupProvider(super.databaseFactory);

  @override
  Future<void> deleteBackup(Backup backupToDelete) {
    /// no op - you can't delete backups we email off.
    throw UnimplementedError();
  }

  @override
  Future<Backup> getBackup(String pathTo) {
    /// no op - you can't retrieve  backups we email off.
    throw UnimplementedError();
  }

  @override

  /// Backups can not be retrieved from email, so this method
  /// returns an empty list.
  Future<List<String>> getBackups() async => <String>[];

  @override
  Future<BackupResult> store(
      {required String pathToDatabase,
      required String pathToZippedBackup,
      required int version}) async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw BackupException('Email backup is not supported on this platform.');
    }

    // await copyDatabase(context
    await sendEmailWithAttachment(pathToZippedBackup);
    return BackupResult(
        pathToSource: pathToDatabase,
        pathToBackup: pathToZippedBackup,
        success: true);
  }

  // Future<void> backup(BuildContext context) async {
  //   await copyDatabase(context);
  //   if (context.mounted) {
  //     await sendEmailWithAttachment(context);
  //   }
  // }

  // Future<void> copyDatabase(BuildContext context) async {
  //   try {
  //     // Get the path to the app's internal database
  //     final dbPath = await DatabaseHelper.pathToDatabase();

  //     // Get the path to the external storage directory
  //     final externalPath = await pathToBackupFile();

  //     final dbFile = File(dbPath);
  //     final backupFile = File(externalPath);

  //     // Copy the database to external storage
  //     await dbFile.copy(backupFile.path);
  //     print('Database copied to: $externalPath');
  //     // ignore: avoid_catches_without_on_clauses
  //   } catch (e) {
  //     if (context.mounted) {
  //       HMBToast.error(context, e.toString());
  //     }
  //   }
  // }

  // Future<String> pathToBackupFile() async {
  //   final directory = await getExternalStorageDirectory();
  //   final externalPath = '${directory!.path}/handyman_backup.db';
  //   return externalPath;
  // }

  Future<void> sendEmailWithAttachment(String pathToZippedBackup) async {
    try {
      final system = await DaoSystem().get();

      if (Strings.isBlank(system?.emailAddress)) {
        throw BackupException(
            'Please enter the Notice/Backup Email address on the System page.');
      }

      final email = Email(
        body: 'Attached is the HMB database backup.',
        subject: 'HMB Database Backup',
        recipients: [
          system!.emailAddress!
        ], // Replace with the recipient's email address
        attachmentPaths: [pathToZippedBackup],
      );

      await FlutterEmailSender.send(email);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      throw BackupException('Error sending email: $e');
    }
  }

  Future<File?> pickBackupFile(BuildContext context) async {
    String? selectedFilePath;
    try {
      if (Platform.isLinux) {
        /// The FilePicker package does a really bad job on linux.
        selectedFilePath = await HMBFilePickerDialog().show(context);
      } else {
        final result = await FilePicker.platform.pickFiles();

        if (result != null && result.files.single.path != null) {
          selectedFilePath = result.files.single.path;
        }
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      throw BackupException('Error picking file: $e');
    }
    return selectedFilePath == null ? null : File(selectedFilePath);
  }

  @override
  Future<void> restoreDatabase(String pathToRestoreDatabase,
      BackupProvider backupProvider, HMBDatabaseFactory databaseFactory) async {
    try {
      final assetScriptSource = AssetScriptSource();
      await super.replaceDatabase(pathToRestoreDatabase, assetScriptSource,
          backupProvider, databaseFactory);

      HMBToast.info('Database restored from: $pathToRestoreDatabase');
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      throw BackupException('Error restoring database: $e');
    }
  }

  Future<void> restore(BuildContext context) async {
    final backupFile = await pickBackupFile(context);
    if (backupFile == null) {
      throw BackupException('No backup file selected.');
    }

    await restoreDatabase(backupFile.path, this, databaseFactory);
  }
}
