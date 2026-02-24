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

import '../../../dao/dao_system.dart';
import '../../../util/flutter/app_title.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';

class ChatGptIntegrationScreen extends StatefulWidget {
  final bool showButtons;

  const ChatGptIntegrationScreen({super.key, this.showButtons = true});

  @override
  ChatGptIntegrationScreenState createState() =>
      ChatGptIntegrationScreenState();
}

class ChatGptIntegrationScreenState extends State<ChatGptIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    setAppTitle('ChatGPT Integration');
    _initializeControllers();
  }

  void _initializeControllers() {
    unawaited(
      DaoSystem().get().then((system) {
        _apiKeyController.text = system.openaiApiKey ?? '';
        setState(() {});
      }),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<bool> save({required bool close}) async {
    if (!_formKey.currentState!.validate()) {
      HMBToast.error('Fix the errors and try again.');
      return false;
    }

    final system = await DaoSystem().get();
    system.openaiApiKey = _apiKeyController.text.trim();
    await DaoSystem().update(system);

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
            Expanded(child: ListView(children: [form])),
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
          'Store your OpenAI API key to enable job summaries and task '
          'extraction during booking import.',
        ),
        const HMBSpacer(height: true),
        TextFormField(
          controller: _apiKeyController,
          decoration: const InputDecoration(
            labelText: 'OpenAI API Key',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
      ],
    ),
  );
}
