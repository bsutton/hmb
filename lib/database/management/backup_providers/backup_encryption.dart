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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-CBC encryption for backup files before cloud upload.
///
/// Key management:
/// - A 256-bit AES key is generated on first backup and stored in
///   platform secure storage (Keychain on iOS, Keystore on Android).
/// - The key never leaves the device in plaintext.
/// - Encrypted files use a random 16-byte IV prepended to the ciphertext.
///
/// File format: [16-byte IV][AES-256-CBC ciphertext]
class BackupEncryption {
  static const _storageKeyName = 'hmb_backup_encryption_key';
  static const _storage = FlutterSecureStorage();

  /// Encrypt [inputFile] and write the result to [outputFile].
  ///
  /// The first 16 bytes of the output are the random IV,
  /// followed by AES-256-CBC ciphertext.
  static Future<void> encryptFile(File inputFile, File outputFile) async {
    final key = await _getOrCreateKey();
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    final plainBytes = await inputFile.readAsBytes();
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    // Write IV + ciphertext
    final output = outputFile.openWrite();
    output.add(iv.bytes);
    output.add(encrypted.bytes);
    await output.flush();
    await output.close();
  }

  /// Decrypt [inputFile] (IV + ciphertext) and write plaintext to [outputFile].
  static Future<void> decryptFile(File inputFile, File outputFile) async {
    final key = await _getOrCreateKey();
    final allBytes = await inputFile.readAsBytes();

    if (allBytes.length < 17) {
      throw const FormatException(
        'Encrypted backup file is too small — missing IV or data.',
      );
    }

    final iv = IV(Uint8List.fromList(allBytes.sublist(0, 16)));
    final cipherBytes = allBytes.sublist(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    final decrypted = encrypter.decryptBytes(
      Encrypted(Uint8List.fromList(cipherBytes)),
      iv: iv,
    );

    await outputFile.writeAsBytes(decrypted);
  }

  /// Check whether a backup encryption key exists.
  ///
  /// If no key exists, the user has never encrypted a backup.
  /// Useful for detecting whether a backup file is encrypted or legacy
  /// plaintext.
  static Future<bool> hasKey() async {
    final stored = await _storage.read(key: _storageKeyName);
    return stored != null;
  }

  /// Retrieve the existing key or generate a new 256-bit AES key.
  static Future<Key> _getOrCreateKey() async {
    final stored = await _storage.read(key: _storageKeyName);

    if (stored != null) {
      return Key(base64.decode(stored));
    }

    // Generate a new 256-bit key
    final key = Key.fromSecureRandom(32);
    await _storage.write(
      key: _storageKeyName,
      value: base64.encode(key.bytes),
    );
    return key;
  }
}
