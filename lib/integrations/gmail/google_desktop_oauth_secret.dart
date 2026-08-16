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

import 'package:path/path.dart' as p;
import 'package:revault_api/revault_api.dart';
import 'package:strings/strings.dart';

import '../../util/dart/exceptions.dart';

/// Reads the development-only Google Desktop OAuth secret from reVault.
///
/// reVault opens its default Vault using the passphrase held in platform
/// storage, then uses the lockbox credential remembered by that Vault. HMB
/// never receives or stores either password.
class GoogleDesktopOAuthSecret {
  static const nativeLibraryEnvironmentKey = 'HMB_REVAULT_LIBRARY';
  static const lockboxEnvironmentKey = 'HMB_GOOGLE_DESKTOP_OAUTH_LOCKBOX';
  static const secretVariableEnvironmentKey =
      'HMB_GOOGLE_DESKTOP_OAUTH_SECRET_VARIABLE';
  static const defaultLockboxPath = 'secrets.lbox';
  static const defaultSecretVariable = '/hmb_desktop_oauth_client_secret';
  static Future<Revault>? _runtime;
  String? _cachedSecret;

  Future<String> read() async {
    final cachedSecret = _cachedSecret;
    if (cachedSecret != null) {
      return cachedSecret;
    }
    final lockboxPath =
        Platform.environment[lockboxEnvironmentKey]?.trim() ??
        defaultLockboxPath;
    final secretVariable =
        Platform.environment[secretVariableEnvironmentKey]?.trim() ??
        defaultSecretVariable;
    if (Strings.isBlank(lockboxPath) || Strings.isBlank(secretVariable)) {
      throw HMBException(
        'Desktop Gmail OAuth lockbox configuration is incomplete.',
      );
    }

    final lockboxFile = File(lockboxPath);
    if (!lockboxFile.existsSync()) {
      throw HMBException(
        'Desktop Gmail OAuth lockbox was not found at $lockboxPath. Set '
        '$lockboxEnvironmentKey when it is stored elsewhere.',
      );
    }

    Lockbox? lockbox;
    try {
      await _loadRuntime();
      lockbox = Lockbox.open(lockboxFile.absolute.path);
      final secret = lockbox.withSecretVariable<String>(
        secretVariable,
        (bytes) => utf8.decode(bytes).trim(),
      );
      if (secret == null || secret.isEmpty) {
        throw HMBException(
          'The Google Desktop OAuth secret variable is empty: '
          '$secretVariable',
        );
      }
      return _cachedSecret = secret;
    } catch (error) {
      if (error is HMBException) {
        rethrow;
      }
      throw HMBException(
        'Could not read the Google Desktop OAuth secret from $lockboxPath. '
        'Ensure the default reVault passphrase is available in platform '
        'storage and its Vault remembers the credential for this lockbox. '
        'Also ensure $secretVariable exists. reVault reported: $error',
      );
    } finally {
      lockbox?.close();
    }
  }

  Future<Revault> _loadRuntime() async {
    try {
      return await (_runtime ??= Revault.load(
        nativeLibraryPath: _nativeLibraryPath(),
      ));
    } catch (_) {
      _runtime = null;
      rethrow;
    }
  }

  String _nativeLibraryPath() {
    final configured = Platform.environment[nativeLibraryEnvironmentKey]
        ?.trim();
    if (!Strings.isBlank(configured)) {
      return File(configured!).absolute.path;
    }

    final libraryName = switch (Platform.operatingSystem) {
      'linux' => 'librevault_api.so',
      'macos' => 'librevault_api.dylib',
      'windows' => 'revault_api.dll',
      _ => throw HMBException(
        'Desktop Gmail OAuth is not supported on '
        '${Platform.operatingSystem}.',
      ),
    };
    return File(
      p.join(
        Directory.current.parent.path,
        'revault',
        'rust',
        'target',
        'release',
        libraryName,
      ),
    ).absolute.path;
  }
}
