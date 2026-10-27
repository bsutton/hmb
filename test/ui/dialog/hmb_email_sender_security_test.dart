import 'dart:convert';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:hmb/ui/dialog/hmb_email_sender.dart';
import 'package:test/test.dart';

void main() {
  test('PowerShell composer keeps untrusted Unicode text in data only', () {
    const untrusted = r'Audit’; Write-Output 314159; $audit=’';
    final expression = powerShellDataExpression(untrusted);

    expect(expression, isNot(contains('Write-Output')));
    expect(expression, isNot(contains('Audit’')));
    final encoded = RegExp(
      r"FromBase64String\('([A-Za-z0-9+/=]*)'\)",
    ).firstMatch(expression);
    expect(encoded, isNotNull);
    expect(utf8.decode(base64Decode(encoded!.group(1)!)), untrusted);
  });

  test('complete Outlook script encodes all untrusted fields', () {
    const payload = r'Claim’; Write-Output 314159; $x=’';
    const email = Email(
      body: '$payload\nsecond line',
      subject: payload,
      recipients: [payload],
      cc: [payload],
      bcc: [payload],
      attachmentPaths: [payload],
    );
    final script = buildWindowsOutlookScript(email);
    expect(script, isNot(contains('Write-Output')));
    expect(script, isNot(contains('Claim’')));
    expect(RegExp('FromBase64String').allMatches(script).length, 6);
    expect(script, contains(r'$mail.Display()'));
  });

  test('long Outlook message remains encoded without size-limited argv', () {
    final body = 'A' * 25000;
    final email = Email(body: body);
    final script = buildWindowsOutlookScript(email);
    expect(script.length, greaterThan(32767));
    expect(script, isNot(contains(body)));
    expect(windowsPowerShellArguments, [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      '-',
    ]);
  });
}
