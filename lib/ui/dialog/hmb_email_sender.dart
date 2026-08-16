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

import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:mailto/mailto.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_system.dart';
import '../../entity/system.dart';
import '../../entity/system_credentials.dart';
import '../../util/dart/exceptions.dart';
import 'google_mail_auth.dart';

class HMBEmailSender {
  static const _backslash = '\u005C';
  final GoogleMailAuth _googleMailAuth;

  HMBEmailSender({GoogleMailAuth? googleMailAuth})
    : _googleMailAuth = googleMailAuth ?? GoogleMailAuth();

  /// Whether HMB has enough configuration to offer direct SMTP delivery.
  Future<bool> canSendDirectly() async {
    final daoSystem = DaoSystem();
    final system = await daoSystem.get();
    if (!_hasSmtpConfig(system)) {
      return false;
    }
    final credentials = await daoSystem.getSmtpCredentials();
    return _missingSmtpFields(system, credentials).isEmpty;
  }

  /// Sends immediately through the configured SMTP service.
  Future<void> sendDirectly(Email email) async {
    final system = await DaoSystem().get();
    if (!_hasSmtpConfig(system)) {
      throw HMBException(
        'Direct SMTP sending is not configured. Configure Settings | '
        'Integrations | SMTP Email.',
      );
    }
    final credentials = await DaoSystem().getSmtpCredentials();
    await _sendSmtp(email, system, credentials);
  }

  /// Opens the platform email composer without sending the message.
  Future<void> openComposer(Email email) async {
    if (!await _trySendNative(email)) {
      throw HMBException('No native email app was available for this message.');
    }
  }

  Future<bool> _trySendNative(Email email) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await FlutterEmailSender.send(email);
      return true;
    }
    if (Platform.isLinux) {
      return _sendLinuxNative(email);
    }
    if (Platform.isMacOS) {
      return _sendMacOsNative(email);
    }
    if (Platform.isWindows) {
      return _sendWindowsNative(email);
    }
    return false;
  }

  Future<void> checkSettings() async {
    final daoSystem = DaoSystem();
    final system = await daoSystem.get();
    final credentials = await daoSystem.getSmtpCredentials();
    final server = await _buildServer(system, credentials);
    await mailer.checkCredentials(server, timeout: const Duration(seconds: 15));
  }

  bool _hasSmtpConfig(SystemConfiguration system) =>
      system.smtpAuthMode == SmtpAuthMode.googleOAuth ||
      Strings.isNotBlank(system.smtpHost);

  Future<bool> _sendLinuxNative(Email email) {
    final args = <String>[
      '--utf8',
      if (Strings.isNotBlank(email.subject)) ...['--subject', email.subject],
      if (Strings.isNotBlank(email.body)) ...['--body', email.body],
      for (final cc in email.cc) ...['--cc', cc],
      for (final bcc in email.bcc) ...['--bcc', bcc],
      for (final path in email.attachmentPaths ?? const <String>[]) ...[
        '--attach',
        path,
      ],
      ...email.recipients,
    ];
    return _runNativeComposer('xdg-email', args);
  }

  Future<bool> _sendMacOsNative(Email email) {
    final attachments = email.attachmentPaths ?? const <String>[];
    if (attachments.isEmpty) {
      return _runNativeComposer('open', [_mailtoUri(email)]);
    }

    final script =
        '''
tell application "Mail"
  set newMessage to make new outgoing message with properties {subject:${_asAppleScriptString(email.subject)}, content:${_asAppleScriptString(email.body)}, visible:true}
  tell newMessage
${email.recipients.map(_appleScriptToRecipient).join('\n')}
${email.cc.map(_appleScriptCcRecipient).join('\n')}
${email.bcc.map(_appleScriptBccRecipient).join('\n')}
${attachments.map(_appleScriptAttachment).join('\n')}
  end tell
  activate
end tell
''';
    return _runNativeComposer('osascript', ['-e', script]);
  }

  Future<bool> _sendWindowsNative(Email email) {
    final attachments = email.attachmentPaths ?? const <String>[];
    if (attachments.isEmpty) {
      return _runNativeComposer('rundll32', [
        'url.dll,FileProtocolHandler',
        _mailtoUri(email),
      ]);
    }

    final script =
        '''
\$outlook = New-Object -ComObject Outlook.Application
\$mail = \$outlook.CreateItem(0)
\$mail.To = ${_asPowerShellString(email.recipients.join(';'))}
\$mail.CC = ${_asPowerShellString(email.cc.join(';'))}
\$mail.BCC = ${_asPowerShellString(email.bcc.join(';'))}
\$mail.Subject = ${_asPowerShellString(email.subject)}
\$mail.Body = ${_asPowerShellString(email.body)}
${attachments.map(_powerShellAttachment).join('\n')}
\$mail.Display()
''';
    return _runNativeComposer('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ]);
  }

  Future<bool> _runNativeComposer(String executable, List<String> args) async {
    try {
      final result = await Process.run(executable, args);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  String _mailtoUri(Email email) => Mailto(
    to: email.recipients,
    cc: email.cc,
    bcc: email.bcc,
    subject: email.subject,
    body: email.body,
  ).toString();

  String _appleScriptToRecipient(String address) =>
      '    make new to recipient at end of to recipients '
      'with properties {address:${_asAppleScriptString(address)}}';

  String _appleScriptCcRecipient(String address) =>
      '    make new cc recipient at end of cc recipients '
      'with properties {address:${_asAppleScriptString(address)}}';

  String _appleScriptBccRecipient(String address) =>
      '    make new bcc recipient at end of bcc recipients '
      'with properties {address:${_asAppleScriptString(address)}}';

  String _appleScriptAttachment(String path) =>
      '    make new attachment with properties '
      '{file name:POSIX file ${_asAppleScriptString(path)}} '
      'at after last paragraph';

  String _asAppleScriptString(String value) {
    final escaped = value
        .replaceAll(_backslash, '$_backslash$_backslash')
        .replaceAll('"', '$_backslash"');
    return '"$escaped"';
  }

  String _asPowerShellString(String value) =>
      "'${value.replaceAll("'", "''")}'";

  String _powerShellAttachment(String path) =>
      '\$mail.Attachments.Add(${_asPowerShellString(path)}) | Out-Null';

  Future<void> _sendSmtp(
    Email email,
    SystemConfiguration system,
    SmtpCredentials credentials,
  ) async {
    final server = await _buildServer(system, credentials);
    final fromEmail = _fromEmail(system);
    final message = mailer.Message()
      ..from = mailer.Address(
        fromEmail,
        Strings.isBlank(system.businessName) ? null : system.businessName,
      )
      ..recipients.addAll(email.recipients)
      ..ccRecipients.addAll(email.cc)
      ..bccRecipients.addAll(email.bcc)
      ..subject = email.subject
      ..text = email.body
      ..attachments.addAll(
        (email.attachmentPaths ?? const <String>[]).map(
          (path) => mailer.FileAttachment(File(path)),
        ),
      );

    await mailer.send(message, server, timeout: const Duration(seconds: 30));
  }

  Future<SmtpServer> _buildServer(
    SystemConfiguration system,
    SmtpCredentials credentials,
  ) async {
    final missing = _missingSmtpFields(system, credentials);
    if (missing.isNotEmpty) {
      throw HMBException(
        'Direct SMTP sending is not configured. Configure Settings | '
        'Integrations | SMTP Email, or use the device mail app where '
        'available. Missing: ${missing.join(', ')}.',
      );
    }

    if (system.smtpProvider == SmtpProvider.gmail &&
        system.smtpAuthMode == SmtpAuthMode.googleOAuth) {
      final token = await _googleMailAuth.getAccessToken();
      return gmailSaslXoauth2(
        _fromEmail(system, token.email),
        token.accessToken,
      );
    }

    return SmtpServer(
      system.smtpHost!.trim(),
      port: system.smtpPort,
      username: system.smtpUsername!.trim(),
      password: credentials.password!.trim(),
      ssl: system.smtpUseSsl,
    );
  }

  List<String> _missingSmtpFields(
    SystemConfiguration system,
    SmtpCredentials credentials,
  ) => <String>[
    if (system.smtpAuthMode != SmtpAuthMode.googleOAuth &&
        Strings.isBlank(system.smtpHost))
      'SMTP host',
    if (system.smtpAuthMode != SmtpAuthMode.googleOAuth && system.smtpPort <= 0)
      'SMTP port',
    if (system.smtpAuthMode == SmtpAuthMode.password &&
        Strings.isBlank(system.smtpUsername))
      'SMTP username',
    if (system.smtpAuthMode == SmtpAuthMode.password &&
        Strings.isBlank(credentials.password))
      'SMTP password',
    if (system.smtpAuthMode == SmtpAuthMode.password &&
        Strings.isBlank(system.smtpFromEmail))
      'SMTP from email',
  ];

  String _fromEmail(SystemConfiguration system, [String? fallback]) {
    final from = system.smtpFromEmail ?? system.smtpUsername ?? fallback;
    if (Strings.isBlank(from)) {
      throw HMBException(
        'Direct SMTP sending is not configured. Configure Settings | '
        'Integrations | SMTP Email, or use the device mail app where '
        'available. Missing: SMTP from email.',
      );
    }
    return from!.trim();
  }
}
