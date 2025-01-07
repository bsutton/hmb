import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path/path.dart';
import 'package:sqflite_common/sqflite.dart' as sql;
import 'package:strings/strings.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../dao/dao_system.dart';
import '../../../../ui/dialog/hmb_file_picker_linux.dart';
import '../../../../util/exceptions.dart';
import '../../../../util/paths.dart'
    if (dart.library.ui) '../../../../util/paths_flutter.dart';
import '../../../versions/asset_script_source.dart';
import '../backup_provider.dart';

class EmailBackupProvider extends BackupProvider {
  EmailBackupProvider(super.databaseFactory);

  @override
  String get name => 'Email Backup';

  @override
  Future<void> deleteBackup(Backup backupToDelete) {
    /// no op - you can't delete backups we email off.
    throw UnimplementedError();
  }

  @override
  Future<File> fetchBackup(Backup backup) {
    /// you can't retrieve emailed backups
    throw UnimplementedError();
  }

  @override

  /// Backups can not be retrieved from email, so this method
  /// returns an empty list.
  Future<List<Backup>> getBackups() async => <Backup>[];

  @override
  Future<BackupResult> store(
      {required String pathToDatabaseCopy,
      required String pathToZippedBackup,
      required int version}) async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw BackupException('Email backup is not supported on this platform.');
    }

    // await copyDatabase(context
    await sendEmailWithAttachment(pathToZippedBackup);
    return BackupResult(
        pathToSource: pathToDatabaseCopy,
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

      if (Strings.isBlank(system.emailAddress)) {
        throw BackupException(
            'Please enter the Notice/Backup Email address on the System page.');
      }

      final email = Email(
        body: 'Attached is the HMB database backup.',
        subject: 'HMB Database Backup',
        recipients: [
          system.emailAddress!
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

  Future<void> restore(BuildContext context) async {
    final backupFile = await pickBackupFile(context);
    if (backupFile == null) {
      throw BackupException('No backup file selected.');
    }

    await WakelockPlus.enable();
    try {
      await performRestore(
        Backup(
            id: 'not used',
            when: DateTime.now(),
            error: 'none',
            pathTo: backupFile.path,
            size: 'unknown',
            status: 'good'),
        AssetScriptSource(),
        databaseFactory,
      );
    } finally {
      await WakelockPlus.disable();
    }
  }

  @override
  Future<String> get photosRootPath => getPhotosRootPath();

  @override
  Future<String> get databasePath async =>
      join(await sql.getDatabasesPath(), 'handyman.db');

  @override
  Future<String> get backupLocation => throw UnimplementedError();
}
