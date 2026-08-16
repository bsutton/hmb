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

import 'dart:ffi';

import 'package:dcli/dcli.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

void windowsInstalller() {
  const protocol = 'hmb';

  final appPath = DartScript.self.pathToScript;

  final protocolKey = text('Software\\Classes\\$protocol');
  final commandKey = text('Software\\Classes\\$protocol\\shell\\open\\command');
  final defaultIconKey = text('Software\\Classes\\$protocol\\DefaultIcon');

  final protocolValue = text('URL:$protocol Protocol');
  final commandValue = text('"$appPath" "%1"');
  final defaultIconValue = text('"$appPath",0');

  // Open the registry key for the protocol
  final hKeyPointer = calloc<Pointer>();
  final result = RegCreateKeyEx(
    HKEY_CURRENT_USER,
    protocolKey,
    null,
    REG_OPTION_NON_VOLATILE,
    KEY_WRITE,
    null,
    hKeyPointer,
    null,
  );

  if (result == ERROR_SUCCESS) {
    final hKey = HKEY(hKeyPointer.value);

    // Set the default value for the protocol key
    RegSetValueEx(
      hKey,
      null,
      REG_SZ,
      protocolValue.cast<Uint8>(),
      (protocolValue.length + 1) * sizeOf<Uint16>(),
    );

    // Set the URL Protocol value
    final urlProtocol = text('URL Protocol');
    RegSetValueEx(hKey, urlProtocol, REG_SZ, null, 0);
    free(urlProtocol);

    // Set the DefaultIcon value
    final hDefaultIconKeyPointer = calloc<Pointer>();
    RegCreateKeyEx(
      hKey,
      defaultIconKey,
      null,
      REG_OPTION_NON_VOLATILE,
      KEY_WRITE,
      null,
      hDefaultIconKeyPointer,
      null,
    );
    final hDefaultIconKey = HKEY(hDefaultIconKeyPointer.value);
    RegSetValueEx(
      hDefaultIconKey,
      null,
      REG_SZ,
      defaultIconValue.cast<Uint8>(),
      (defaultIconValue.length + 1) * sizeOf<Uint16>(),
    );
    hDefaultIconKey.close();
    free(hDefaultIconKeyPointer);

    // Set the command value
    final hCommandKeyPointer = calloc<Pointer>();
    RegCreateKeyEx(
      hKey,
      commandKey,
      null,
      REG_OPTION_NON_VOLATILE,
      KEY_WRITE,
      null,
      hCommandKeyPointer,
      null,
    );
    final hCommandKey = HKEY(hCommandKeyPointer.value);
    RegSetValueEx(
      hCommandKey,
      null,
      REG_SZ,
      commandValue.cast<Uint8>(),
      (commandValue.length + 1) * sizeOf<Uint16>(),
    );
    hCommandKey.close();
    free(hCommandKeyPointer);

    hKey.close();
  } else {
    print('Failed to create registry key. Error code: $result');
  }

  // Free allocated memory
  free(protocolKey);
  free(commandKey);
  free(defaultIconKey);
  free(protocolValue);
  free(commandValue);
  free(defaultIconValue);
  free(hKeyPointer);
}

PCWSTR text(String text) => text.toPcwstr();
