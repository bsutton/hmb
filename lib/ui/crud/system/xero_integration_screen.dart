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
import '../../../util/flutter/app_title.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';

class XeroIntegrationScreen extends StatefulWidget {
  final bool showButtons;

  const XeroIntegrationScreen({super.key, this.showButtons = true});

  @override
  XeroIntegrationScreenState createState() => XeroIntegrationScreenState();
}

class XeroIntegrationScreenState extends State<XeroIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _xeroClientIdController = TextEditingController();
  final _xeroClientSecretController = TextEditingController();
  final _invoiceLineAccountCodeController = TextEditingController();
  final _invoiceLineItemCodeController = TextEditingController();
  var _xeroEnabled = true;

  @override
  void initState() {
    super.initState();
    setAppTitle('Xero Integration');
    _initializeControllers();
  }

  void _initializeControllers() {
    unawaited(
      DaoSystem().get().then((system) {
        _xeroClientIdController.text = system.xeroClientId ?? '';
        _xeroClientSecretController.text = system.xeroClientSecret ?? '';
        _invoiceLineAccountCodeController.text =
            system.invoiceLineRevenueAccountCode ?? '';
        _invoiceLineItemCodeController.text =
            system.invoiceLineInventoryItemCode ?? '';
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
      ..invoiceLineRevenueAccountCode = _invoiceLineAccountCodeController.text
      ..invoiceLineInventoryItemCode = _invoiceLineItemCodeController.text
      ..enableXeroIntegration = _xeroEnabled;
    await DaoSystem().update(system);

    if (mounted) {
      HMBToast.info('saved');
      if (close) {
        context.go('/home/settings/integrations');
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
    } else {
      return form;
    }
  }

  Form _buildForm() => Form(
    key: _formKey,
    child: HMBColumn(
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
This Revenue Account Code must existing in Xero'''),
        HMBTextField(
          controller: _invoiceLineItemCodeController,
          labelText: 'Invoice Line Inventory Item Code',
        ).help('Item Code', '''
The Inventory Item Code to assign to invoice lines when uploading them to Xero.\n
This Inventory Item Code must exist in Xero'''),
      ],
    ),
  );
}
