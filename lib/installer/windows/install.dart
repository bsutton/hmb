import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../../util/dcli_stub.dart'
    if (Platform.isWindows) 'package:dcli/dcli.dart';

void windowsInstalller() {
  const protocol = 'hmb';

  final appPath = DartScript.self().pathToScript;

  final protocolKey = text('Software\\Classes\\$protocol');
  final commandKey = text('Software\\Classes\\$protocol\\shell\\open\\command');
  final defaultIconKey = text('Software\\Classes\\$protocol\\DefaultIcon');

  final protocolValue = text('URL:$protocol Protocol');
  final commandValue = text('"$appPath" "%1"');
  final defaultIconValue = text('"$appPath",0');

  // Open the registry key for the protocol
  final hKey = calloc<HKEY>();
  final result = RegCreateKeyEx(
    HKEY_CURRENT_USER,
    protocolKey,
    0,
    nullptr,
    0, // REG_OPTION_NON_VOLATILE is 0
    REG_SAM_FLAGS.KEY_WRITE,
    nullptr,
    hKey,
    nullptr,
  );

  if (result == WIN32_ERROR.ERROR_SUCCESS) {
    // Set the default value for the protocol key
    RegSetValueEx(
        hKey.value,
        nullptr,
        0,
        REG_VALUE_TYPE.REG_SZ,
        protocolValue.cast<BYTE>(),
        (protocolValue.length + 1) * sizeOf<Uint16>());

    // Set the URL Protocol value
    RegSetValueEx(
        hKey.value, text('URL Protocol'), 0, REG_VALUE_TYPE.REG_SZ, nullptr, 0);

    // Set the DefaultIcon value
    final hDefaultIconKey = calloc<HKEY>();
    RegCreateKeyEx(hKey.value, defaultIconKey, 0, nullptr, 0,
        REG_SAM_FLAGS.KEY_WRITE, nullptr, hDefaultIconKey, nullptr);
    RegSetValueEx(
        hDefaultIconKey.value,
        nullptr,
        0,
        REG_VALUE_TYPE.REG_SZ,
        defaultIconValue.cast<BYTE>(),
        (defaultIconValue.length + 1) * sizeOf<Uint16>());
    RegCloseKey(hDefaultIconKey.value);

    // Set the command value
    final hCommandKey = calloc<HKEY>();
    RegCreateKeyEx(hKey.value, commandKey, 0, nullptr, 0,
        REG_SAM_FLAGS.KEY_WRITE, nullptr, hCommandKey, nullptr);
    RegSetValueEx(
        hCommandKey.value,
        nullptr,
        0,
        REG_VALUE_TYPE.REG_SZ,
        commandValue.cast<BYTE>(),
        (commandValue.length + 1) * sizeOf<Uint16>());
    RegCloseKey(hCommandKey.value);

    RegCloseKey(hKey.value);
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
  free(hKey);
}

Pointer<Utf16> text(String text) => text.toNativeUtf16();
