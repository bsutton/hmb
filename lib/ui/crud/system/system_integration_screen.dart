import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_system.dart';
import '../../../util/app_title.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/layout/hmb_spacer.dart';
import '../../widgets/widgets.g.dart';

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
  final _invoiceLineAccountCodeController = TextEditingController();
  final _invoiceLineItemCodeController = TextEditingController();
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
        _invoiceLineAccountCodeController.text =
            system.invoiceLineAccountCode ?? '';
        _invoiceLineItemCodeController.text = system.invoiceLineItemCode ?? '';
        _xeroEnabled = system.enableXeroIntegration;
        setState(() {});
      }),
    );
  }

  @override
  void dispose() {
    _xeroClientIdController.dispose();
    _xeroClientSecretController.dispose();
    _invoiceLineAccountCodeController.dispose();
    _invoiceLineItemCodeController.dispose();
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
      ..invoiceLineAccountCode = _invoiceLineAccountCodeController.text
      ..invoiceLineItemCode = _invoiceLineItemCodeController.text
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
              onCancel: () async => context.pop(),
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
        HMBTextField(
          controller: _invoiceLineAccountCodeController,
          labelText: 'Invoice Line Revenue Account Code',
        ).help('Account Code', '''
The Revenue Account Code to assign to invoice lines when uploading them to Xero.
This Revenue Code must already existing in Xero'''),
        HMBTextField(
          controller: _invoiceLineItemCodeController,
          labelText: 'Invoice Line Revenue Account Name',
        ).help('Account Name', '''
The Revenue Account Name to assign to invoice lines when uploading them to Xero.\n
This Revenue Name must match the name in Xero for the above Account Code'''),
      ],
    ),
  );
}
