import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_system.dart';
import '../../../util/app_title.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/hmb_spacer.dart';
import '../../widgets/save_and_close.dart';

class SystemIntegrationScreen extends StatefulWidget {
  const SystemIntegrationScreen({super.key, this.showButtons = true});

  final bool showButtons;

  @override
  // ignore: library_private_types_in_public_api
  SystemIntegrationScreenState createState() => SystemIntegrationScreenState();
}

class SystemIntegrationScreenState extends State<SystemIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _xeroClientIdController = TextEditingController();

  final _xeroClientSecretController = TextEditingController();
  var _xeroEnabled = true;

  @override
  void initState() {
    super.initState();
    setAppTitle('System Integrations');
    _initializeControllers();
  }

  void _initializeControllers() {
    unawaited(
      DaoSystem().get().then((system) {
        _xeroClientIdController.text = system.xeroClientId ?? '';
        _xeroClientSecretController.text = system.xeroClientSecret ?? '';
        _xeroEnabled = system.enableXeroIntegration;
        setState(() {});
      }),
    );
  }

  @override
  void dispose() {
    _xeroClientIdController.dispose();
    _xeroClientSecretController.dispose();
    super.dispose();
  }

  Future<bool> save({required bool close}) async {
    if (!_formKey.currentState!.validate()) {
      HMBToast.error('Fix the errors and try again.');
      return false;
    }

    if (_xeroEnabled &&
        (Strings.isBlank(_xeroClientIdController.text) ||
            Strings.isBlank(_xeroClientSecretController.text))) {
      HMBToast.error('You must provide the Client Id and Secret');
      return false;
    }

    final system = await DaoSystem().get();
    // Save the form data
    system
      ..xeroClientId = _xeroClientIdController.text
      ..xeroClientSecret = _xeroClientSecretController.text
      ..enableXeroIntegration = _xeroEnabled;
    await DaoSystem().update(system);

    if (mounted) {
      HMBToast.info('saved');
      if (close) {
        context.go('/dashboard/settings');
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    /// For when the form is displayed in the system wizard
    final form = _buildForm();
    if (widget.showButtons) {
      return Scaffold(
        body: Column(
          children: [
            SaveAndClose(
              onSave: save,
              showSaveOnly: false,
              onCancel: () async => context.go('/home'),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(children: [form]),
              ),
            ),
          ],
        ),
      );
    } else {
      return form;
    }
  }

  Form _buildForm() => Form(
    key: _formKey,
    child: Column(
      children: [
        const Text('Enable Xero integration to upload Invoices to Xero'),
        const HMBSpacer(height: true),

        // ← New switch:
        SwitchListTile(
          title: const Text('Enable Xero Integration'),
          subtitle: const Text('Turn off to disable invoice uploads to Xero'),
          value: _xeroEnabled,
          onChanged: (v) => setState(() => _xeroEnabled = v),
        ),

        HMBTextField(
          controller: _xeroClientIdController,
          labelText: 'Xero Client ID',
          keyboardType: TextInputType.number,
        ),
        HMBTextField(
          controller: _xeroClientSecretController,
          labelText: 'Xero Client Secret',
          keyboardType: TextInputType.number,
        ),
      ],
    ),
  );
}
