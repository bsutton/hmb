import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    if (_formKey.currentState!.validate()) {
      final system = await DaoSystem().get();
      // Save the form data
      system
        ..xeroClientId = _xeroClientIdController.text
        ..xeroClientSecret = _xeroClientSecretController.text;

      await DaoSystem().update(system);

      if (mounted) {
        HMBToast.info('saved');
        if (close) {
          context.go('/jobs');
        }
      }
      return true;
    } else {
      HMBToast.error('Fix the errors and try again.');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showButtons) {
      return Scaffold(
        body: Column(
          children: [
            SaveAndClose(
              onSave: ({required close}) async => save(close: close),
              showSaveOnly: false,
              onCancel: () async => context.go('/jobs'),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(children: [_buildForm()]),
              ),
            ),
          ],
        ),
      );
    } else {
      /// For when the form is displayed in the system wizard
      return _buildForm();
    }
  }

  Form _buildForm() => Form(
    key: _formKey,
    child: Column(
      children: [
        const Text('''
HMB can generate and (optionally) upload invoices to the Xero Accounting package.
To take advantage of this feature you need to use Xero as your accounting
package and you need a Xero developer account.'''),
        const HMBSpacer(height: true),
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
