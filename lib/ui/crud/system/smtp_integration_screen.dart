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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_system.dart';
import '../../../entity/system.dart';
import '../../../entity/system_credentials.dart';
import '../../../util/flutter/app_title.dart';
import '../../dialog/google_mail_auth.dart';
import '../../dialog/hmb_email_sender.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';

class SmtpIntegrationScreen extends StatefulWidget {
  const SmtpIntegrationScreen({super.key});

  @override
  State<SmtpIntegrationScreen> createState() => _SmtpIntegrationScreenState();
}

class _SmtpIntegrationScreenState extends State<SmtpIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '587');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fromEmailController = TextEditingController();
  final _googleOAuthClientIdController = TextEditingController();
  var _provider = SmtpProvider.custom;
  var _authMode = SmtpAuthMode.password;
  var _useSsl = false;
  var _testing = false;
  var _googleConnected = false;

  @override
  void initState() {
    super.initState();
    setAppTitle('SMTP Email');
    _initializeControllers();
  }

  void _initializeControllers() {
    unawaited(
      Future.wait([DaoSystem().get(), DaoSystem().getSmtpCredentials()])
          .then((results) {
            final system = results[0] as SystemConfiguration;
            final credentials = results[1] as SmtpCredentials;
            _hostController.text = system.smtpHost ?? '';
            _portController.text = system.smtpPort.toString();
            _usernameController.text = system.smtpUsername ?? '';
            _passwordController.text = credentials.password ?? '';
            _fromEmailController.text = system.smtpFromEmail ?? '';
            _googleOAuthClientIdController.text =
                system.smtpGoogleOAuthClientId ?? '';
            _provider = system.smtpProvider;
            _authMode =
                _availableAuthModes(_provider).contains(system.smtpAuthMode)
                ? system.smtpAuthMode
                : _defaultAuthModeForProvider(_provider);
            _useSsl = system.smtpUseSsl;
            return GoogleMailAuth().isConnected();
          })
          .then((connected) {
            _googleConnected = connected;
            if (mounted) {
              setState(() {});
            }
          }),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fromEmailController.dispose();
    _googleOAuthClientIdController.dispose();
    super.dispose();
  }

  Future<bool> save({required bool close}) async {
    if (!_formKey.currentState!.validate()) {
      HMBToast.error('Fix the errors and try again.');
      return false;
    }
    final port = int.tryParse(_portController.text.trim());
    if (port == null || port <= 0 || port > 65535) {
      HMBToast.error('SMTP port must be between 1 and 65535.');
      return false;
    }
    final daoSystem = DaoSystem();
    final system = await daoSystem.getForUpdate();
    system
      ..smtpProvider = _provider
      ..smtpAuthMode = _authMode
      ..smtpHost = _blankToNull(_hostController.text)
      ..smtpPort = port
      ..smtpUsername = _blankToNull(_usernameController.text)
      ..smtpFromEmail = _blankToNull(_fromEmailController.text)
      ..smtpGoogleOAuthClientId = _blankToNull(
        _googleOAuthClientIdController.text,
      )
      ..smtpUseSsl = _useSsl;
    await daoSystem.updateConfiguration(system);
    await daoSystem.updateSmtpCredentials(
      SmtpCredentials(password: _blankToNull(_passwordController.text)),
    );
    if (mounted) {
      HMBToast.info('saved');
      if (close) {
        context.go('/home/settings/integrations');
      }
    }
    return true;
  }

  Future<void> _testSettings() async {
    if (!await save(close: false)) {
      return;
    }
    setState(() => _testing = true);
    try {
      await HMBEmailSender().checkSettings();
      if (mounted) {
        HMBToast.info('SMTP settings verified');
      }
    } catch (e) {
      if (mounted) {
        HMBToast.error(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _connectGmail() async {
    if (!await save(close: false)) {
      return;
    }
    setState(() => _testing = true);
    try {
      await GoogleMailAuth().connect();
      if (mounted) {
        setState(() => _googleConnected = true);
        HMBToast.info('Gmail connected');
      }
    } catch (e) {
      if (mounted) {
        HMBToast.error(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _disconnectGmail() async {
    await GoogleMailAuth().disconnect();
    if (mounted) {
      setState(() => _googleConnected = false);
      HMBToast.info('Gmail disconnected');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: HMBColumn(
      children: [
        SaveAndClose(
          onSave: save,
          showSaveOnly: false,
          onCancel: () async => context.pop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Form(
                key: _formKey,
                child: HMBColumn(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Configure SMTP so HMB can send emails with attachments.',
                    ),
                    DropdownButtonFormField<SmtpProvider>(
                      key: ValueKey(_provider),
                      initialValue: _provider,
                      decoration: const InputDecoration(
                        labelText: 'Email Provider',
                      ),
                      items: SmtpProvider.values
                          .map(
                            (provider) => DropdownMenuItem(
                              value: provider,
                              child: Text(provider.label),
                            ),
                          )
                          .toList(),
                      onChanged: (provider) {
                        if (provider == null) {
                          return;
                        }
                        setState(() {
                          _provider = provider;
                          _applyProviderDefaults(provider);
                        });
                      },
                    ),
                    if (_availableAuthModes(_provider).length > 1)
                      DropdownButtonFormField<SmtpAuthMode>(
                        key: ValueKey('${_provider.name}-${_authMode.name}'),
                        initialValue: _authMode,
                        decoration: const InputDecoration(
                          labelText: 'Authentication',
                        ),
                        items: _availableAuthModes(_provider)
                            .map(
                              (mode) => DropdownMenuItem(
                                value: mode,
                                child: Text(mode.label),
                              ),
                            )
                            .toList(),
                        onChanged: (mode) {
                          if (mode == null) {
                            return;
                          }
                          setState(() => _authMode = mode);
                        },
                      ),
                    HMBTextField(
                      controller: _hostController,
                      labelText: 'SMTP Host',
                      enabled: _authMode != SmtpAuthMode.googleOAuth,
                    ),
                    HMBTextField(
                      controller: _portController,
                      labelText: 'SMTP Port',
                      keyboardType: TextInputType.number,
                      enabled: _authMode != SmtpAuthMode.googleOAuth,
                    ),
                    HMBTextField(
                      controller: _usernameController,
                      labelText: _authMode == SmtpAuthMode.googleOAuth
                          ? 'Google Account Email'
                          : 'SMTP Username',
                    ),
                    if (_authMode == SmtpAuthMode.password)
                      HMBTextField(
                        controller: _passwordController,
                        labelText: _provider == SmtpProvider.gmail
                            ? 'Gmail App Password'
                            : 'SMTP Password',
                        obscureText: true,
                      ),
                    HMBTextField(
                      controller: _fromEmailController,
                      labelText: 'From Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (_authMode == SmtpAuthMode.password)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Use SSL connection'),
                        subtitle: const Text(
                          'Leave off for normal STARTTLS on port 587.',
                        ),
                        value: _useSsl,
                        onChanged: (value) => setState(() => _useSsl = value),
                      ),
                    if (_provider == SmtpProvider.gmail &&
                        _authMode == SmtpAuthMode.googleOAuth)
                      ..._buildGoogleOAuthFields(),
                    HMBButton.withIcon(
                      label: _testing ? 'Testing...' : 'Test Settings',
                      hint: 'Verify the SMTP email settings',
                      icon: _testing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      enabled: !_testing,
                      onPressed: _testSettings,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return Strings.isBlank(trimmed) ? null : trimmed;
  }

  List<Widget> _buildGoogleOAuthFields() => [
    HMBTextField(
      controller: _googleOAuthClientIdController,
      labelText: 'Google Desktop OAuth Client ID',
    ),
    Text(
      _googleConnected
          ? 'Gmail OAuth is connected.'
          : 'Gmail OAuth opens Google in your browser and stores the '
                'refresh token securely.',
    ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        HMBButton.withIcon(
          label: _googleConnected ? 'Reconnect Gmail' : 'Connect Gmail',
          hint: 'Authorize HMB to send mail through Gmail',
          icon: const Icon(Icons.link),
          enabled: !_testing,
          onPressed: _connectGmail,
        ),
        if (_googleConnected)
          HMBButton.withIcon(
            label: 'Disconnect',
            hint: 'Remove saved Gmail OAuth credentials',
            icon: const Icon(Icons.link_off),
            enabled: !_testing,
            onPressed: _disconnectGmail,
          ),
      ],
    ),
  ];

  List<SmtpAuthMode> _availableAuthModes(SmtpProvider provider) =>
      provider == SmtpProvider.gmail && GoogleMailAuth.isSupported()
      ? SmtpAuthMode.values
      : const [SmtpAuthMode.password];

  void _applyProviderDefaults(SmtpProvider provider) {
    _authMode = _defaultAuthModeForProvider(provider);
    switch (provider) {
      case SmtpProvider.custom:
        return;
      case SmtpProvider.gmail:
        _hostController.text = 'smtp.gmail.com';
        _portController.text = '587';
        _useSsl = false;
      case SmtpProvider.outlook:
        _hostController.text = 'smtp.office365.com';
        _portController.text = '587';
        _useSsl = false;
      case SmtpProvider.icloud:
        _hostController.text = 'smtp.mail.me.com';
        _portController.text = '587';
        _useSsl = false;
    }
  }

  SmtpAuthMode _defaultAuthModeForProvider(SmtpProvider provider) =>
      provider == SmtpProvider.gmail && GoogleMailAuth.isSupported()
      ? SmtpAuthMode.googleOAuth
      : SmtpAuthMode.password;
}
