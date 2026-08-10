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
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_system.dart';
import '../../../entity/system.dart';
import '../../../entity/system_credentials.dart';
import '../../../util/flutter/app_title.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';

class IhServerIntegrationScreen extends StatefulWidget {
  final bool showButtons;

  const IhServerIntegrationScreen({super.key, this.showButtons = true});

  @override
  IhServerIntegrationScreenState createState() =>
      IhServerIntegrationScreenState();
}

class IhServerIntegrationScreenState extends State<IhServerIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  var _enabled = false;
  final _rand = Random.secure();

  @override
  void initState() {
    super.initState();
    setAppTitle('ihserver Integration');
    _initializeControllers();
  }

  void _initializeControllers() {
    unawaited(
      Future.wait([
        DaoSystem().get(),
        DaoSystem().getIhserverCredentials(),
      ]).then((results) {
        final system = results[0] as SystemConfiguration;
        final credentials = results[1] as IhserverCredentials;
        _urlController.text = system.ihserverUrl ?? '';
        _tokenController.text = credentials.token ?? '';
        _enabled = system.enableIhserverIntegration;
        setState(() {});
      }),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<bool> save({required bool close}) async {
    if (!_formKey.currentState!.validate()) {
      HMBToast.error('Fix the errors and try again.');
      return false;
    }

    if (_enabled &&
        (Strings.isBlank(_urlController.text) ||
            Strings.isBlank(_tokenController.text))) {
      HMBToast.error('You must provide the Server URL and Token');
      return false;
    }

    if (_enabled) {
      final baseUrl = _urlController.text.trim();
      final parsed = Uri.tryParse(baseUrl);
      if (parsed == null ||
          !parsed.hasScheme ||
          parsed.scheme.toLowerCase() != 'https' ||
          Strings.isBlank(parsed.host)) {
        HMBToast.error('ihserver URL must be a valid https:// URL');
        return false;
      }
    }

    final daoSystem = DaoSystem();
    final system = await daoSystem.getForUpdate();
    system
      ..ihserverUrl = _urlController.text.trim()
      ..enableIhserverIntegration = _enabled;
    await daoSystem.updateConfiguration(system);
    await daoSystem.updateIhserverCredentials(
      IhserverCredentials(token: _tokenController.text.trim()),
    );

    if (mounted) {
      if (widget.showButtons) {
        HMBToast.info('saved');
      }
      if (close) {
        context.go('/home/settings/integrations');
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final form = _buildForm();
    if (widget.showButtons) {
      return Scaffold(
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
                children: [form],
              ),
            ),
          ],
        ),
      );
    }
    return form;
  }

  Form _buildForm() => Form(
    key: _formKey,
    child: HMBColumn(
      children: [
        const Text(
          'Enable ihserver integration to import website enquiries as jobs.',
        ),
        const HMBSpacer(height: true),
        SwitchListTile(
          title: const Text('Enable ihserver Integration'),
          subtitle: const Text('Turn on to enable booking imports'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        HMBTextField(
          controller: _urlController,
          labelText: 'ihserver Base URL',
          keyboardType: TextInputType.url,
          required: _enabled,
        ).help('Example', 'https://ivanhoehandyman.com.au'),
        HMBTextField(
          controller: _tokenController,
          labelText: 'Access Token',
          keyboardType: TextInputType.visiblePassword,
          required: _enabled,
          obscureText: true,
          suffixIcon: IconButton(
            tooltip: 'Generate token',
            icon: const Icon(Icons.auto_fix_high),
            onPressed: () {
              final token = _generateToken();
              _tokenController.text = token;
              unawaited(Clipboard.setData(ClipboardData(text: token)));
              HMBToast.info('Token copied to clipboard');
              setState(() {});
            },
          ),
        ),
      ],
    ),
  );

  String _generateToken() {
    final bytes = List<int>.generate(32, (_) => _rand.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
