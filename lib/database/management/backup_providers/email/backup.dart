import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:strings/strings.dart';

import '../../../../dao/dao_system.dart';
import '../../../../util/exceptions.dart';
import '../../../../widgets/hmb_toast.dart';
import '../../database_helper.dart';
import '../backup_provider.dart';

class EmailBackupProvider extends BackupProvider {
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

  Future<File?> pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      throw BackupException('Error picking file: $e');
    }
    return null;
  }

  @override
  Future<void> restoreDatabase() async {
    try {
      final backupFile = await pickBackupFile();
      if (backupFile == null) {
        throw BackupException('No backup file selected.');
      }

      await super.replaceDatabase(backupFile.path);

      HMBToast.info('Database restored from: ${backupFile.path}');
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      throw BackupException('Error restoring database: $e');
    }
  }
}
